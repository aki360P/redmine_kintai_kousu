require 'redmine'

module RedmineKintaiKousu
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_sidebar(context = {})
      # ガントチャート画面のみ表示
      controller = context[:controller]
      return '' unless controller && controller.controller_name == 'gantts' && controller.action_name == 'show'
      
      context[:controller].send(:render_to_string, {
        partial: 'kintai_kousu/gantt_sidebar',
        locals: context
      })
    end
  end
end
