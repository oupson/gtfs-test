DROP TABLE IF EXISTS STOP_TIME;

DROP TABLE IF EXISTS TRIP;

DROP TABLE IF EXISTS STOP;

DROP TABLE IF EXISTS SHAPE;

DROP TABLE IF EXISTS ROUTE;

DROP TABLE IF EXISTS CALENDAR_DAY;

DROP TABLE IF EXISTS CALENDAR_DATE;

DROP TABLE IF EXISTS CALENDAR;

DROP TABLE IF EXISTS AGENCY;

DROP TABLE IF EXISTS GTFS_FILE;

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
    serviceId         VARCHAR(42) NOT NULL,
    calendarStartDate VARCHAR(8)  NOT NULL,
    calendarEndDate   VARCHAR(8)  NOT NULL,
    CONSTRAINT PK_CALENDAR PRIMARY KEY (serviceId)
);

CREATE TABLE CALENDAR_DAY
(
    calendarDayServiceId VARCHAR(42) NOT NULL,
    calendarDay          SMALLINT    NOT NULL,
    CONSTRAINT PK_CALENDAR_DAY PRIMARY KEY (calendarDayServiceId, calendarDay),
    CONSTRAINT FK_CALENDAR_DAY_CALENDAR FOREIGN KEY (calendarDayServiceId) REFERENCES CALENDAR (serviceId)
);

CREATE TABLE CALENDAR_DATE
(
    serviceId                 VARCHAR(42) NOT NULL,
    calendarDate              VARCHAR(8)  NOT NULL,
    calendarDateExceptionType INTEGER     NOT NULL CHECK ( calendarDateExceptionType >= 1 AND calendarDateExceptionType <= 2 ),
    CONSTRAINT PK_CALENDAR_DATE PRIMARY KEY (serviceId, calendarDate)
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
    stopTimeStopId    VARCHAR(42) NOT NULL,
    stopTimeTripId    VARCHAR(42) NOT NULL,
    stopTimeSequence  INTEGER     NOT NULL,
    stopTimeArrival   VARCHAR(8)  NULL,
    stopTimeDeparture VARCHAR(8)  NULL,
    CONSTRAINT PK_STOP_TIME PRIMARY KEY (stopTimeStopId, stopTimeTripId, stopTimeSequence),
    CONSTRAINT FK_STOP_TIME_STOP FOREIGN KEY (stopTimeStopId) REFERENCES STOP (stopId),
    CONSTRAINT FK_STOP_TIME_TRIP FOREIGN KEY (stopTimeTripId) REFERENCES TRIP (tripId)
);

CREATE TABLE GTFS_FILE
(
    gtfsFileName TEXT    NOT NULL,
    gtfsFileCrc  INTEGER NOT NULL,
    CONSTRAINT PK_GTFS_FILE PRIMARY KEY (gtfsFileName)
);
