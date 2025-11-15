require "google/cloud/ai_platform"

class GeminiController < ApplicationController
  def test
    # 1. 사용자님의 프로젝트 ID
    project_id = "kmj-project-2025"
    location = "us-central1"
    model = "gemini-1.0-pro" # 텍스트 전용 모델

    # API 클라이언트 설정
    client = Google::Cloud::Aiplatform::V1::PredictionServiceClient.new do |config|
      config.endpoint = "#{location}-aiplatform.googleapis.com"
    end

    endpoint = "projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}"
    prompt = "Ruby on Rails의 MVC 패턴에 대해 초보자가 이해하기 쉽게 설명해줘."

    # Gemini에 요청 보내기
    response = client.predict(
      endpoint: endpoint,
      instances: [ { "prompt": prompt } ]
    )

    # 결과를 View로 전달하기 위해 @reply 변수에 저장
    @reply = response.predictions.first["content"]
  end
end
