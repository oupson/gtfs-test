require 'net/http'
require 'zip'
require 'csv'
require "sqlite3"
require 'ruby-progressbar'

puts "Downloading file ..."
gtfs_uri = URI.parse(ENV["GTFS_URL"])
Net::HTTP.start(gtfs_uri.host, gtfs_uri.port,
                :use_ssl => gtfs_uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new gtfs_uri

    http.request request do |response|
        File.open('gtfs.zip', 'w') do |f|
            response.read_body do |chunk|
                f.write chunk
            end
        end
    end
end

puts "Creating database ..."
# Open a database
db = SQLite3::Database.new "data.db"

db.execute_batch <<-SQL
drop table if exists CALENDAR;

drop table if exists STOP_TIME;

drop table if exists STOP;

drop table if exists TRIP;

drop table if exists ROUTE;

drop table if exists AGENCY;

drop table if exists SHAPE;

-- TODO ID LENGTH

CREATE TABLE AGENCY
(
    agencyId       VARCHAR(42) NULL,
    agencyName     VARCHAR(42) NOT NULL,
    agencyUrl      TEXT        NOT NULL,
    agencyTimeZone TEXT        NOT NULL,
    CONSTRAINT PK_AGENCY PRIMARY KEY (agencyId)
);

-- TODO START AND END DATE
CREATE TABLE CALENDAR
(
    serviceId          VARCHAR(42) NOT NULL,
    isServingMonday    BOOLEAN     NOT NULL,
    isServingTuesday   BOOLEAN     NOT NULL,
    isServingWednesday BOOLEAN     NOT NULL,
    isServingThursday  BOOLEAN     NOT NULL,
    isServingFriday    BOOLEAN     NOT NULL,
    isServingSaturday  BOOLEAN     NOT NULL,
    isServingSunday    BOOLEAN     NOT NULL,
    CONSTRAINT PK_CALENDAR PRIMARY KEY (serviceId)
);

CREATE TABLE ROUTE
(
    routeId        VARCHAR(42) NOT NULL,
    routeShortName VARCHAR(24) NULL,
    routeLongName  VARCHAR(42) NOT NULL,
    routeDesc      TEXT        NULL,
    routeType      INTEGER     NOT NULL CHECK ( routeType >= 0 AND routeType <= 12 ),
    routeColor     VARCHAR(6)  NULL,
    routeTextColor VARCHAR(6)  NULL,
    routeAgencyId  VARCHAR(42) NOT NULL,
    CONSTRAINT PK_ROUTE PRIMARY KEY (routeId),
    CONSTRAINT FK_ROUTE_AGENCY FOREIGN KEY (routeAgencyId) REFERENCES AGENCY (agencyId),
    CONSTRAINT ROUTE_NAME_NOT_NULL CHECK ( routeShortName IS NOT NULL OR routeLongName IS NOT NULL )
);

CREATE TABLE SHAPE
(
    shapeId   VARCHAR(42) NOT NULL,
    shapeLine TEXT        NOT NULL,
    CONSTRAINT PK_SHAPE PRIMARY KEY (shapeId)
);

CREATE TABLE STOP
(
    stopId            VARCHAR(42) NOT NULL,
    stopCode          VARCHAR(16) NULL,
    stopName          VARCHAR(42) NULL,
    stopDesc          TEXT        NULL,
    stopLatitude      REAL        NULL,
    stopLongitude     REAL        NULL,
    stopZoneId        VARCHAR(42) NULL,
    stopLocationType  INTEGER     NULL CHECK ( stopLocationType >= 0 AND stopLocationType <= 4 ),
    stopPlaformCode   VARCHAR(16) NULL,
    stopParentStation VARCHAR(42) NULL,
    CONSTRAINT PK_STOP PRIMARY KEY ("stopid"),
    CONSTRAINT FK_STOP_PARENT_STOP FOREIGN KEY (stopParentStation) REFERENCES STOP (stopId)
);

CREATE TABLE TRIP
(
    tripId          VARCHAR(42) NOT NULL,
    tripServiceId   VARCHAR(42) NOT NULL,
    tripHeadSign    TEXT        NULL,
    tripDirectionId INTEGER     NULL CHECK ( tripDirectionId IS NULL OR (tripDirectionId >= 0 AND tripDirectionId <= 1) ),
    tripShapeId     VARCHAR(42) NULL,
    tripRouteId     VARCHAR(42) NOT NULL,
    CONSTRAINT PK_TRIP PRIMARY KEY (tripId),
    CONSTRAINT FK_TRIP_SHAPE FOREIGN KEY (tripShapeId) REFERENCES SHAPE (shapeId),
    CONSTRAINT FK_TRIP_ROUTE FOREIGN KEY (tripRouteId) REFERENCES ROUTE (routeId)
);

CREATE TABLE STOP_TIME
(
    stopTimeStopId             VARCHAR(42) NOT NULL,
    stopTimeTripId             VARCHAR(42) NOT NULL,
    stopTimeSequence           INTEGER     NOT NULL,
    stopTimeArrival            VARCHAR(8)  NULL,
    stopTimeDeparture          VARCHAR(8)  NULL,
    stopTimeRealtimeArrival    VARCHAR(8)  NULL     DEFAULT NULL, -- TODO Type
    stopTimeRealtimeDeparture  VARCHAR(8)  NULL     DEFAULT NULL, -- TODO Type
    stopTimeRealtimeIsCanceled BOOLEAN     NOT NULL DEFAULT FALSE,
    CONSTRAINT PK_STOP_TIME PRIMARY KEY (stopTimeStopId, stopTimeTripId, stopTimeSequence),
    CONSTRAINT FK_STOP_TIME_STOP FOREIGN KEY (stopTimeStopId) REFERENCES STOP (stopId),
    CONSTRAINT FK_STOP_TIME_TRIP FOREIGN KEY (stopTimeTripId) REFERENCES TRIP (tripId)
);
SQL

puts "Extracting gtfs ..."
unless Dir.exist?("gtfs")
    Dir.mkdir("gtfs")
end

Zip::File.open("gtfs.zip") do |zipfile|
    zipfile.each do |entry|
        path = File.join("gtfs", entry.name)
        unless File.exist?(path)
            zipfile.extract(entry, path)
        end
    end
end

puts "Filling database ..."

agency = CSV.read("gtfs/agency.txt", headers: true)
p = ProgressBar.create(:title => "Agencies", :total => agency.length)
agency.each { |a|
    db.execute "INSERT INTO AGENCY(agencyId, agencyName, agencyURL, agencyTimeZone) VALUES (?, ?, ?, ?)", a["agency_id"], a["agency_name"], a["agency_url"], a["agency_timezone"]
    p.increment
}

calendars = CSV.read("gtfs/calendar.txt", headers: true)
p = ProgressBar.create(:title => "Calendars", :total => calendars.length)
db.transaction do
    calendars.each do |a|
        db.execute "insert into CALENDAR (serviceId, isServingMonday, isServingTuesday, isServingWednesday, isServingThursday, isServingFriday, isServingSaturday, isServingSunday) values (?, ?, ?, ?, ?, ?, ?, ?);",
                   a["service_id"], a["monday"], a["tuesday"], a["wednesday"], a["thursday"], a["friday"], a["saturday"], a["sunday"] #,start_date,end_date
        p.increment
    end
end

routes = CSV.read("gtfs/routes.txt", headers: true)
p = ProgressBar.create(:title => "Routes", :total => calendars.length)
db.transaction do
    routes.each do |a|
        db.execute "insert into ROUTE (routeId, routeShortName, routeLongName, routeDesc, routeType, routeColor, routeTextColor, routeAgencyId) values (?, ?, ?, ?, ?, ?, ?, ?)",
                   # route_id,agency_id,route_short_name,route_long_name,route_type,route_color,route_text_color
                   a["route_id"], a["route_short_name"], a["route_long_name"], a["route_desc"], a["route_type"], a["route_color"], a["route_text_color"], a["agency_id"]
        p.increment
    end
end

shapes = CSV.read("gtfs/shapes.txt", headers: true)
p = ProgressBar.create(:title => "Shapes", :total => shapes.length)
last_shape_id = nil
db.transaction do
    shapes.each do |a|
        if last_shape_id != a["shape_id"]
            db.execute "insert into SHAPE (shapeId, shapeLine) values (?, ?)",
                       a["shape_id"], ""
            last_shape_id = a["shape_id"]
            p.increment
        end
    end
end

total = `wc -l < gtfs/stops.txt`.to_i - 1

p = ProgressBar.create(:title => "Stops", :total => total)
db.transaction do
    stm = db.prepare "insert into STOP (stopId, stopCode, stopName, stopDesc, stopLatitude, stopLongitude, stopZoneId, stopLocationType, stopPlaformCode, stopParentStation) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    CSV.foreach("gtfs/stops.txt", headers: true) do |a|
        if last_shape_id != a["shape_id"]
            stm.bind_params a["stop_id"], a["stop_code"], a["stop_name"], a["stop_desc"], a["stop_lat"], a["stop_lon"], a["zone_id"], a["location_type"], a["platform_code"], a["parent_station"]
            stm.execute!
            stm.reset!
            p.increment
        end
    end
end

total = `wc -l < gtfs/trips.txt`.to_i - 1
p = ProgressBar.create(:title => "Trips", :total => total)
db.transaction do
    stm = db.prepare "insert into TRIP (tripId, tripServiceId, tripHeadSign, tripDirectionId, tripShapeId, tripRouteId) values (?, ?, ?, ?, ?, ?)"
    CSV.foreach("gtfs/trips.txt", headers: true) do |a|
        stm.bind_params a["trip_id"], a["service_id"], a["trip_headsign"], a["direction_id"], a["shape_id"], a["route_id"]
        stm.execute!
        stm.reset!
        p.increment
    end
end

total = `wc -l < gtfs/stop_times.txt`.to_i - 1
p = ProgressBar.create(:title => "StopTimes", :total => total)
index_i = 1
max = (total / 100) * 100
csv = CSV.open("gtfs/stop_times.txt", headers: true)
db.transaction do
    stm = db.prepare "insert into STOP_TIME (stopTimeStopId, stopTimeTripId, stopTimeSequence, stopTimeArrival, stopTimeDeparture) values " + ["(?, ?, ?, ?, ?)"].cycle(100).to_a.join(",")
    (0...max).each { |_|
        a = csv.shift

        stm.bind_param index_i, a["stop_id"]
        stm.bind_param index_i + 1, a["trip_id"]
        stm.bind_param index_i + 2, a["stop_sequence"]
        stm.bind_param index_i + 3, a["arrival_time"]
        stm.bind_param index_i + 4, a["departure_time"]

        index_i += 5
        if index_i == 501
            index_i = 1
            stm.execute!
            stm.reset!
            p.progress += 100
        end
    }

    stm = db.prepare "insert into STOP_TIME (stopTimeStopId, stopTimeTripId, stopTimeSequence, stopTimeArrival, stopTimeDeparture) values (?, ?, ?, ?, ?)"
    csv.each do |a|
        stm.bind_params a["stop_id"], a["trip_id"], a["stop_sequence"], a["arrival_time"], a["departure_time"]
        stm.execute!
        stm.reset!
        p.increment
    end
end