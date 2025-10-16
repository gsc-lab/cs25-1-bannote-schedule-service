Rails.application.routes.draw do
  # 그룹 → 일정 → 일정링크 → 일정파일 
  resources :groups do
    resources :schedules do
      resources :schedule_links do
        resources :schedule_files
      end
    end
  end
end
