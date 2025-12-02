module DatetimeHelper
  # 문자열 → Time 객체 파싱
  def parse_datetime(str)
    return nil if str.blank?

    if str =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/
      return Time.zone.strptime(str, "%Y-%m-%dT:%H:%M:%S")
    end

    if str =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/
      return Time.zone.strptime(str, "%Y-%m-%dT:%H:%M")
    end

    Time.zone.parse(str)
  end

  def combine_date_time(date, hhmm)
    h, m = hhmm.split(":").map(&:to_i)
    Time.zone.local(date.year, date.month, date.day, h, m, 0)
  end

  def hhmm_to_minutes(hhmm)
    return Float::INFINITY if hhmm.blank?
    h, m = hhmm.split(":").map(&:to_i)
    (h * 60) + m
  end
end
