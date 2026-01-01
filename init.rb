Redmine::Plugin.register :redmine_kintai_kousu do
  name 'Redmine Kintai Kousu Plugin'
  author 'Your Name'
  description 'Time entry management plugin for Redmine'
  version '0.0.1'
  url 'https://github.com/yourusername/redmine_kintai_kousu'
  author_url 'https://github.com/yourusername'

  menu :account_menu, :kintai_kousu, { controller: 'kintai_kousu', action: 'index' },
       caption: :label_kintai_kousu,
       if: Proc.new { User.current.logged? },
       before: :my_account
end
