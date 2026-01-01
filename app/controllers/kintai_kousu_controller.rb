class KintaiKousuController < ApplicationController
  before_action :require_login
  protect_from_forgery with: :null_session, only: [:create, :update, :destroy]

  def index
    # 年月パラメータの取得（年→月の順）
    @year = params[:year] ? params[:year].to_i : Date.today.year
    @month = params[:month] ? params[:month].to_i : Date.today.month
    
    # 月が範囲外の場合は年を調整
    if @month < 1
      @month = 12
      @year -= 1
    elsif @month > 12
      @month = 1
      @year += 1
    end
    
    @date = Date.new(@year, @month, 1)
    
    # 月の最初と最後の日
    @first_day = @date.beginning_of_month
    @last_day = @date.end_of_month
    
    # その月の全工数を取得
    @time_entries = TimeEntry
      .where(user_id: User.current.id)
      .where(spent_on: @first_day..@last_day)
      .includes(:project, :issue, :activity)
      .order('spent_on ASC, created_on ASC')
    
    # 日付ごとに工数を集計
    @daily_hours = {}
    (1..@last_day.day).each do |day|
      @daily_hours[day] = 0.0
    end
    
    # プロジェクトごと、日付ごとに工数を集計
    @project_daily_hours = {}
    
    @time_entries.each do |entry|
      day = entry.spent_on.day
      project = entry.project
      
      # 全体の日次集計
      @daily_hours[day] += entry.hours
      
      # プロジェクトごとの日次集計
      @project_daily_hours[project] ||= {}
      (1..@last_day.day).each do |d|
        @project_daily_hours[project][d] ||= 0.0
      end
      @project_daily_hours[project][day] += entry.hours
    end
    
    # 月合計
    @total_hours = @time_entries.sum(:hours)
    
    # プロジェクトごとの月合計
    @project_totals = {}
    @project_daily_hours.each do |project, daily_hours|
      @project_totals[project] = daily_hours.values.sum
    end
  end
  
  def show
    @year = params[:year].to_i
    @month = params[:month].to_i
    @day = params[:day].to_i
    @date = Date.new(@year, @month, @day)
    
    # その日の既存工数を取得
    @existing_entries = TimeEntry
      .where(user_id: User.current.id, spent_on: @date)
      .includes(:project, :issue, :activity)
      .order('created_on DESC')
    
    # アクティビティ一覧
    @activities = TimeEntryActivity.active.order(:position)
    
    # ユーザーがメンバーのプロジェクト一覧
    @projects = Project
      .joins(:members)
      .where("members.user_id = ?", User.current.id)
      .where("projects.status = ?", Project::STATUS_ACTIVE)
      .order("projects.name")
      .distinct
    
    # ユーザーが担当のチケット一覧（プロジェクトごとに分類、クローズ済みも含む）
    issues = Issue.visible
      .joins(:project)
      .where("issues.assigned_to_id = ?", User.current.id)
      .where("projects.status = ?", Project::STATUS_ACTIVE)
      .includes(:project, :status, :priority, :parent, :tracker)
      .order("projects.name, issues.root_id, issues.lft")
    
    # プロジェクトごとにチケットをグループ化
    @issues_by_project = {}
    @projects.each do |project|
      project_issues = issues.select { |i| i.project_id == project.id }
      # ルートチケットのみを取得（子チケットは後で再帰的に表示）
      @issues_by_project[project] = project_issues.select { |i| i.parent_id.nil? }
    end
    
    # トラッカー一覧を取得（フィルター用）
    @trackers = issues.map(&:tracker).uniq.sort_by(&:position)
  end
  
  def create
    @year = params[:year].to_i
    @month = params[:month].to_i
    @day = params[:day].to_i
    @date = Date.new(@year, @month, @day)
    
    respond_to do |format|
      if params[:time_entry]
        project = Project.find(params[:time_entry][:project_id])
        
        time_entry = TimeEntry.new(
          user: User.current,
          project: project,
          spent_on: @date,
          hours: params[:time_entry][:hours],
          activity_id: params[:time_entry][:activity_id],
          comments: params[:time_entry][:comments]
        )
        
        if params[:time_entry][:issue_id].present?
          time_entry.issue_id = params[:time_entry][:issue_id]
        end
        
        if time_entry.save
          format.html do
            flash[:notice] = l(:notice_successful_create)
            redirect_to kintai_kousu_path(year: @year, month: @month)
          end
          format.json do
            render json: {
              success: true,
              message: l(:notice_successful_create),
              time_entry: {
                id: time_entry.id,
                project: {
                  id: time_entry.project.id,
                  name: time_entry.project.name
                },
                issue: time_entry.issue ? {
                  id: time_entry.issue.id,
                  subject: time_entry.issue.subject
                } : nil,
                hours: time_entry.hours.to_f,
                activity: {
                  id: time_entry.activity.id,
                  name: time_entry.activity.name
                },
                comments: time_entry.comments,
                spent_on: time_entry.spent_on,
                created_on: time_entry.created_on
              }
            }, status: :created
          end
        else
          format.html do
            flash[:error] = time_entry.errors.full_messages.join(', ')
            redirect_to action: 'show', year: @year, month: @month, day: @day
          end
          format.json do
            render json: {
              success: false,
              errors: time_entry.errors.full_messages
            }, status: :unprocessable_entity
          end
        end
      else
        format.html { redirect_to kintai_kousu_path(year: @year, month: @month) }
        format.json { render json: { success: false, errors: ['No data provided'] }, status: :bad_request }
      end
    end
  end

  def update
    begin
      @time_entry = TimeEntry.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.json { render json: { success: false, errors: ['工数が見つかりません'] }, status: :not_found }
      end
      return
    end
    
    # 権限チェック：自分の工数のみ編集可能
    unless @time_entry.user_id == User.current.id
      respond_to do |format|
        format.json { render json: { success: false, errors: ['権限がありません'] }, status: :forbidden }
      end
      return
    end
    
    respond_to do |format|
      @time_entry.attributes = {
        project_id: params[:time_entry][:project_id],
        issue_id: params[:time_entry][:issue_id].presence,
        hours: params[:time_entry][:hours],
        activity_id: params[:time_entry][:activity_id],
        comments: params[:time_entry][:comments]
      }
      
      if @time_entry.save
        format.json do
          render json: {
            success: true,
            message: l(:notice_successful_update),
            time_entry: {
              id: @time_entry.id,
              project: {
                id: @time_entry.project.id,
                name: @time_entry.project.name
              },
              issue: @time_entry.issue ? {
                id: @time_entry.issue.id,
                subject: @time_entry.issue.subject
              } : nil,
              hours: @time_entry.hours.to_f,
              activity: {
                id: @time_entry.activity.id,
                name: @time_entry.activity.name
              },
              comments: @time_entry.comments
            }
          }, status: :ok
        end
      else
        format.json do
          render json: {
            success: false,
            errors: @time_entry.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    begin
      @time_entry = TimeEntry.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.json { render json: { success: false, errors: ['工数が見つかりません'] }, status: :not_found }
      end
      return
    end
    
    # 権限チェック：自分の工数のみ削除可能
    unless @time_entry.user_id == User.current.id
      respond_to do |format|
        format.json { render json: { success: false, errors: ['権限がありません'] }, status: :forbidden }
      end
      return
    end
    
    respond_to do |format|
      if @time_entry.destroy
        format.json do
          render json: {
            success: true,
            message: l(:notice_successful_delete),
            time_entry_id: @time_entry.id
          }, status: :ok
        end
      else
        format.json do
          render json: {
            success: false,
            errors: @time_entry.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
