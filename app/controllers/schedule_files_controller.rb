class ScheduleFilesController < ApplicationController
  before_action :set_group
  before_action :set_schedule
  before_action :set_schedule_link
  before_action :set_schedule_file, only: [:show, :destroy]

  # 1. 파일 목록 조회 (GET)
  def index
    files = @schedule_link.schedule_files
    render json: files
  end

  # 2. 단일 파일 조회 (GET)
  def show
    render json: @schedule_file
  end

  # 3. 파일 업로드 (POST)
  def create
    file = @schedule_link.schedule_files.new(schedule_file_params)
    if file.save
      render json: file, status: :created
    else
      render json: file.errors, status: :unprocessable_entity
    end
  end

  # 4. 파일 삭제 (DELETE)
  def destroy
    @schedule_file.destroy
    head :no_content
  end

  private

  # ----------------------------
  # 공통 로드 메서드
  # ----------------------------

  def set_group
    @group = Group.find(params[:group_id])
  end

  def set_schedule
    @schedule = @group.schedules.find(params[:schedule_id])
  end

  def set_schedule_link
    @schedule_link = @schedule.schedule_link
  end

  def set_schedule_file
    @schedule_file = @schedule_link.schedule_files.find(params[:id])
  end

  # ----------------------------
  # Strong Parameter
  # ----------------------------

  def schedule_file_params
    params.require(:schedule_file).permit(:file_name, :file_url, :uploaded_by)
  end
end
