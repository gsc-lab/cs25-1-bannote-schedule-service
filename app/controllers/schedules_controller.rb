class SchedulesController < ApplicationController
  before_action :set_group
  before_action :set_schedule, only: [ :show, :update, :destroy ]


  # 1. 일정 목록 조회 (GET)
  def index
    schedules = @group.schedules.includes(:schedule_link)
    render json: schedules
  end

  # 2. 일정 상세 조회 (GET)
  def show
    render json: @schedule
  end

  # 3. 일정 생성 (POST)
  def create
    ActiveRecord::Base.transaction do
      # 3-1. 일정링크 생성
      schedule_link = ScheduleLink.create!(
        title: params[:schedule][:title] || "새 일정",
        start_time: params[:schedule][:start_time] || Time.current,
        end_time: params[:schedule][:end_time] || (Time.current + 1.hour),
        created_by: params[:schedule][:created_by]
      )

      # 3-2. 일정 생성
      schedule = @group.schedules.new(
        color: params[:schedule][:color],
        created_by: params[:schedule][:created_by],
        schedule_link: schedule_link
      )

      if schedule.save
        render json: schedule, status: :created
      else
        render json: schedule.errors, status: :unprocessable_entity
      end
    end
  end

  # 4. 일정 수정 (PATCH)
  def update
    if @schedule.schedule_link.update(schedule_link_params)
      @schedule.update(schedule_params)
      render json: @schedule
    else
      render json: @schedule.errors, status: :unprocessable_entity
    end
  end

  # 5. 일정 삭제 (DELETE)
  def destroy
    @schedule.destroy
    head :no_content
  end

  private

  # 그룹 ID로 그룹을 미리 불러오기
  def set_group
    @group = Group.find(params[:group_id])
  end

  # 일정 ID로 일정 불러오기
  def set_schedule
    @schedule = @group.schedules.find(params[:id])
  end

  # 일정 속성 허용
  def schedule_params
    params.require(:schedule).permit(:color, :created_by)
  end

  # 일정링크 속성 허용
  def schedule_link_params
    params.require(:schedule).permit(:title, :start_time, :end_time)
  end
end
