module KintaiKousuHelper
  def render_issue_hierarchy(issues, level = 0)
    return '' if issues.empty?
    
    html = '<ul style="list-style: none; padding-left: ' + (level * 20).to_s + 'px; margin: 5px 0;">'
    
    issues.each do |issue|
      indent = level > 0 ? ('&nbsp;' * (level * 2) + '└ ').html_safe : ''
      
      html += '<li class="issue-item tracker-' + issue.tracker_id.to_s + '" style="padding: 3px 0; border-bottom: 1px solid #eee;">'
      html += indent
      html += content_tag(:span, issue.tracker.name, style: 'display: inline-block; padding: 2px 6px; margin-right: 5px; background-color: #ddd; border-radius: 3px; font-size: 0.85em;')
      
      # チケット番号 - 外部リンク用
      html += link_to("##{issue.id}", issue_path(issue), target: '_blank', style: 'font-weight: bold;')
      html += ' '
      
      # チケット件名 - クリックで工数フォームに入力
      html += link_to(
        issue.subject.truncate(60), 
        '#', 
        onclick: "selectIssueForTimeEntry(#{issue.id}); return false;",
        style: 'cursor: pointer; color: #169; text-decoration: none;',
        title: 'クリックして工数を登録'
      )
      html += ' '
      
      # 外部リンクアイコン
      html += link_to('🔗', issue_path(issue), target: '_blank', style: 'font-size: 0.8em; text-decoration: none;', title: 'チケットを別タブで開く')
      html += ' '
      
      html += content_tag(:span, issue.status.name, style: 'color: #999; font-size: 0.9em;')
      
      # 子チケットを再帰的に表示
      children = issue.children.visible.where.not(status: IssueStatus.where(is_closed: true))
      if children.any?
        html += render_issue_hierarchy(children, level + 1)
      end
      
      html += '</li>'
    end
    
    html += '</ul>'
    html.html_safe
  end
end
