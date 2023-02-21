# frozen_string_literal: true

require_relative "gtfs/version"

require 'net/http'
require 'zip'
require 'csv'
require 'sqlite3'
require 'ruby-progressbar'

module Gtfs
  class Error < StandardError; end

  # Your code goes here...

  class GtfsData
    def initialize(db_path = 'data.db')
      @db = SQLite3::Database.new db_path
    end

    def import_data(gtfs_uri)
      puts 'Downloading file ...'
      Net::HTTP.start(gtfs_uri.host, gtfs_uri.port,
                      use_ssl: gtfs_uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new gtfs_uri

        http.request request do |response|
          File.open('gtfs.zip', 'w') do |f|
            response.read_body do |chunk|
              f.write chunk
            end
          end
        end
      end

      @db.execute_batch IO.read('CREATE.sql')

      puts 'Extracting gtfs ...'
      unless Dir.exist?('gtfs')
        Dir.mkdir('gtfs')
      end

      Zip::File.open('gtfs.zip') do |zipfile|
        zipfile.each do |entry|
          path = File.join('gtfs', entry.name)
          unless File.exist?(path)
            zipfile.extract(entry, path)
          end
        end
      end

      puts 'Filling database ...'

      agency = CSV.read('gtfs/agency.txt', headers: true)
      p = ProgressBar.create(title: 'Agencies', total: agency.length)
      agency.each do |a|
        @db.execute 'INSERT INTO AGENCY(agencyId, agencyName, agencyURL, agencyTimeZone) VALUES (?, ?, ?, ?)', a['agency_id'], a['agency_name'], a['agency_url'], a['agency_timezone']
        p.increment
      end

      calendars = CSV.read('gtfs/calendar.txt', headers: true)
      p = ProgressBar.create(title: 'Calendars', total: calendars.length)
      @db.transaction do
        calendars.each do |a|
          @db.execute 'insert into CALENDAR (serviceId, calendarStartDate, calendarEndDate) values (?, ?, ?);',
                      a['service_id'], a['start_date'], a['end_date']

          if a['monday'] == '1'
            @db.execute 'INSERT INTO CALENDAR_DAY(calendarDayServiceId, calendarDay) VALUES (?, ?)',
                        a['service_id'], 0
          end

          if a['tuesday'] == '1'
            @db.execute 'INSERT INTO CALENDAR_DAY(calendarDayServiceId, calendarDay) VALUES (?, ?)',
                        a['service_id'], 1
          end

          if a['wednesday'] == '1'
            @db.execute 'INSERT INTO CALENDAR_DAY(calendarDayServiceId, calendarDay) VALUES (?, ?)',
                        a['service_id'], 2
          end

          if a['thursday'] == '1'
            @db.execute 'INSERT INTO CALENDAR_DAY(calendarDayServiceId, calendarDay) VALUES (?, ?)',
                        a['service_id'], 3
          end

          if a['friday'] == '1'
            @db.execute 'INSERT INTO CALENDAR_DAY(calendarDayServiceId, calendarDay) VALUES (?, ?)',
                        a['service_id'], 4
          end

          if a['saturday'] == '1'
            @db.execute 'INSERT INTO CALENDAR_DAY(calendarDayServiceId, calendarDay) VALUES (?, ?)',
                        a['service_id'], 5
          end

          if a['sunday'] == '1'
            @db.execute 'INSERT INTO CALENDAR_DAY(calendarDayServiceId, calendarDay) VALUES (?, ?)',
                        a['service_id'], 6
          end

          p.increment
        end
      end

      calendar_dates = CSV.read('gtfs/calendar_dates.txt', headers: true)
      p = ProgressBar.create(title: 'Calendar Dates', total: calendar_dates.length)
      @db.transaction do
        calendar_dates.each do |a|
          @db.execute 'insert into CALENDAR_DATE (serviceId, calendarDate, calendarDateExceptionType) VALUES (?, ?, ?);',
                      a['service_id'], a['date'], a['exception_type']
          p.increment
        end
      end

      routes = CSV.read('gtfs/routes.txt', headers: true)
      p = ProgressBar.create(title: 'Routes', total: calendars.length)
      @db.transaction do
        routes.each do |a|
          @db.execute 'insert into ROUTE (routeId, routeShortName, routeLongName, routeDesc, routeType, routeColor, routeTextColor, routeAgencyId) values (?, ?, ?, ?, ?, ?, ?, ?)',
                      # route_id,agency_id,route_short_name,route_long_name,route_type,route_color,route_text_color
                      a['route_id'], a['route_short_name'], a['route_long_name'], a['route_desc'], a['route_type'], a['route_color'], a['route_text_color'], a['agency_id']
          p.increment
        end
      end

      shapes = CSV.read('gtfs/shapes.txt', headers: true)
      p = ProgressBar.create(title: 'Shapes', total: shapes.length)
      last_shape_id = nil
      @db.transaction do
        shapes.each do |a|
          next unless last_shape_id != a['shape_id']

          @db.execute 'insert into SHAPE (shapeId, shapeLine) values (?, ?)',
                      a['shape_id'], ''
          last_shape_id = a['shape_id']
          p.increment
        end
      end

      total = `wc -l < gtfs/stops.txt`.to_i - 1

      p = ProgressBar.create(title: 'Stops', total: total)
      @db.transaction do
        stm = @db.prepare 'insert into STOP (stopId, stopCode, stopName, stopDesc, stopLatitude, stopLongitude, stopZoneId, stopLocationType, stopPlaformCode, stopParentStation) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        CSV.foreach('gtfs/stops.txt', headers: true) do |a|
          if last_shape_id != a['shape_id']
            stm.bind_params a['stop_id'], a['stop_code'], a['stop_name'], a['stop_desc'], a['stop_lat'], a['stop_lon'], a['zone_id'], a['location_type'], a['platform_code'], a['parent_station']
            stm.execute!
            stm.reset!
            p.increment
          end
        end
      end

      total = `wc -l < gtfs/trips.txt`.to_i - 1
      p = ProgressBar.create(title: 'Trips', total: total)
      @db.transaction do
        stm = @db.prepare 'insert into TRIP (tripId, tripServiceId, tripHeadSign, tripDirectionId, tripShapeId, tripRouteId) values (?, ?, ?, ?, ?, ?)'
        CSV.foreach('gtfs/trips.txt', headers: true) do |a|
          stm.bind_params a['trip_id'], a['service_id'], a['trip_headsign'], a['direction_id'], a['shape_id'], a['route_id']
          stm.execute!
          stm.reset!
          p.increment
        end
      end

      total = `wc -l < gtfs/stop_times.txt`.to_i - 1
      p = ProgressBar.create(title: 'StopTimes', total: total)
      index_i = 1
      max = (total / 100) * 100
      csv = CSV.open('gtfs/stop_times.txt', headers: true)
      @db.transaction do
        if false
          stm = @db.prepare 'insert into STOP_TIME (stopTimeStopId, stopTimeTripId, stopTimeSequence, stopTimeArrival, stopTimeDeparture) values ' + ['(?, ?, ?, ?, ?)'].cycle(100).to_a.join(',')
          (0...max).each do |_|
            a = csv.shift

            stm.bind_param index_i, a['stop_id']
            stm.bind_param index_i + 1, a['trip_id']
            stm.bind_param index_i + 2, a['stop_sequence']
            stm.bind_param index_i + 3, a['arrival_time']
            stm.bind_param index_i + 4, a['departure_time']

            index_i += 5
            next unless index_i == 501

            index_i = 1
            stm.execute!
            stm.reset!
            p.progress += 100
          end
        end

        stm = @db.prepare 'insert into STOP_TIME (stopTimeStopId, stopTimeTripId, stopTimeSequence, stopTimeArrival, stopTimeDeparture) values (?, ?, ?, ?, ?)'
        csv.each do |a|
          stm.bind_params a['stop_id'], a['trip_id'], a['stop_sequence'], a['arrival_time'], a['departure_time']
          stm.execute!
          stm.reset!
          p.increment
        end
      end
    end
  end
end

