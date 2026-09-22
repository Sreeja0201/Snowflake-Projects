-- ============================================================
-- PROJECT 14A: E-Commerce Web Event Analytics
-- Data Lake vs Data Warehouse
-- Environment: Snowflake SQL
-- ============================================================


USE DATABASE SNOWFLAKE_LEARNING_DB;
USE SCHEMA PROJECT14A;




CREATE OR REPLACE TABLE STAGE_RAW_EVENTS (
    RAW_RECORD_TEXT VARCHAR,
    INGESTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);



INSERT INTO STAGE_RAW_EVENTS (RAW_RECORD_TEXT)
SELECT column1
FROM VALUES

('{"event_id":"EVT-8001","timestamp":"2026-07-01T08:15:00Z","user_id":1001,"page":"checkout","action":"purchase","order":{"total":12500.00,"shipping_cost":250.00,"tax":625.00,"items":2}}'),

('{"event_id":"EVT-8002","timestamp":"2026-07-01T08:20:00Z","user_id":1002,"page":"product_detail","action":"view","order":null}'),

('{"event_id":"EVT-8003","timestamp":"2026-07-01T08:35:00Z","user_id":1003,"page":"cart","action":"add_to_cart","order":null}'),

('{"event_id":"EVT-8004","timestamp":"2026-07-01T09:10:00Z","user_id":1004,"page":"checkout","action":"purchase","order":{"total":45000.00,"shipping_cost":500.00,"tax":2250.00,"items":5}}'),

('{"event_id":"EVT-8005","timestamp":"2026-07-01T09:45:00Z","user_id":1001,"page":"product_detail","action":"view","order":null}'),

('{"event_id":"EVT-8006","timestamp":"2026-07-02T10:00:00Z","user_id":1005,"page":"checkout","action":"purchase","order":{"total":18000.00,"shipping_cost":300.00,"tax":900.00,"items":3},"promo_code":"SUMMER20","discount_amount":3600.00}'),

('{"event_id":"EVT-8007","timestamp":"2026-07-02T10:15:00Z","user_id":1002,"page":"checkout","action":"purchase","order":{"total":8500.00,"shipping_cost":150.00,"tax":425.00,"items":1},"promo_code":"WELCOME10","discount_amount":850.00}'),

('{"event_id":"EVT-8008","timestamp":"2026-07-02T10:30:00Z","user_id":1006,"page":"cart","action":"add_to_cart","order":null,"promo_code":null,"discount_amount":0.00}'),

('{"event_id":"EVT-8009","timestamp":"2026-07-02T11:00:00Z","user_id":1003,"page":"checkout","action":"purchase","order":{"total":32000.00,"shipping_cost":400.00,"tax":1600.00,"items":4},"promo_code":"FESTIVE15","discount_amount":4800.00}'),

('{"event_id":"EVT-8010","timestamp":"2026-07-02T11:20:00Z","user_id":1007,"page":"product_detail","action":"view","order":null,"promo_code":null,"discount_amount":0.00}'),

('{"event_id":"EVT-8011","timestamp":"2026-07-03T12:00:00Z","user_id":1008,"page":"checkout","action":"purchase","order":{"total":0.00,"shipping_cost":0.00,"tax":0.00,"items":0},"promo_code":"FREEPASS","discount_amount":0.00}'),

('INVALID_JSON_PAYLOAD_MALFORMED_STRING');


CREATE OR REPLACE TABLE LAKE_RAW_EVENTS (
    RAW_DATA VARIANT,
    INGESTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO LAKE_RAW_EVENTS (RAW_DATA)
SELECT TRY_PARSE_JSON(RAW_RECORD_TEXT)
FROM STAGE_RAW_EVENTS
WHERE TRY_PARSE_JSON(RAW_RECORD_TEXT) IS NOT NULL;



SELECT
    RAW_DATA:event_id::STRING AS EVENT_ID,
    TO_TIMESTAMP_NTZ(RAW_DATA:timestamp::STRING) AS EVENT_TIME,
    RAW_DATA:user_id::NUMBER AS USER_ID,
    RAW_DATA:action::STRING AS ACTION,
    RAW_DATA:order.total::NUMBER(18,2) AS ORDER_TOTAL,
    RAW_DATA:promo_code::STRING AS PROMO_CODE
FROM LAKE_RAW_EVENTS
ORDER BY EVENT_TIME, EVENT_ID;


SELECT
    RAW_DATA:event_id::STRING AS EVENT_ID,

    RAW_DATA:order.total::NUMBER(18,2) AS ORDER_TOTAL,

    RAW_DATA:order.shipping_cost::NUMBER(18,2) AS SHIPPING_COST,

    RAW_DATA:order.tax::NUMBER(18,2) AS TAX,

    COALESCE(
        RAW_DATA:discount_amount::NUMBER(18,2),
        0
    ) AS DISCOUNT_AMOUNT,

    (
        RAW_DATA:order.total::NUMBER(18,2)
        - COALESCE(
            RAW_DATA:order.shipping_cost::NUMBER(18,2),
            0
        )
        - COALESCE(
            RAW_DATA:order.tax::NUMBER(18,2),
            0
        )
        - COALESCE(
            RAW_DATA:discount_amount::NUMBER(18,2),
            0
        )
    ) AS NET_REVENUE

FROM LAKE_RAW_EVENTS

WHERE RAW_DATA:order.total::NUMBER(18,2) > 0

ORDER BY EVENT_ID;


SELECT
    COUNT(*) AS TOTAL_EVENTS,

    SUM(
        IFF(
            RAW_DATA:action::STRING = 'purchase'
            AND RAW_DATA:order.total::NUMBER(18,2) > 0,
            1,
            0
        )
    ) AS TOTAL_PURCHASES,

    ROUND(
        100.0 *
        SUM(
            IFF(
                RAW_DATA:action::STRING = 'purchase'
                AND RAW_DATA:order.total::NUMBER(18,2) > 0,
                1,
                0
            )
        )
        / COUNT(*),
        2
    ) AS CONVERSION_RATE_PCT,

    SUM(
        IFF(
            RAW_DATA:order.total::NUMBER(18,2) > 0,
            RAW_DATA:order.total::NUMBER(18,2),
            0
        )
    ) AS TOTAL_GROSS_REVENUE,

    ROUND(
        SUM(
            IFF(
                RAW_DATA:action::STRING = 'purchase'
                AND RAW_DATA:order.total::NUMBER(18,2) > 0,
                RAW_DATA:order.total::NUMBER(18,2),
                0
            )
        )
        /
        NULLIF(
            SUM(
                IFF(
                    RAW_DATA:action::STRING = 'purchase'
                    AND RAW_DATA:order.total::NUMBER(18,2) > 0,
                    1,
                    0
                )
            ),
            0
        ),
        2
    ) AS AVERAGE_ORDER_VALUE

FROM LAKE_RAW_EVENTS;


CREATE OR REPLACE TABLE DW_STRUCTURED_EVENTS (
    EVENT_ID        VARCHAR(50),
    EVENT_TIME      TIMESTAMP_NTZ,
    USER_ID         NUMBER,
    PAGE            VARCHAR(100),
    ACTION          VARCHAR(50),
    ORDER_TOTAL     NUMBER(18,2),
    SHIPPING_COST   NUMBER(18,2),
    TAX             NUMBER(18,2),
    ITEMS           NUMBER,
    PROMO_CODE      VARCHAR(100),
    DISCOUNT_AMOUNT NUMBER(18,2),
    NET_REVENUE     NUMBER(18,2)
);


INSERT INTO DW_STRUCTURED_EVENTS (
    EVENT_ID,
    EVENT_TIME,
    USER_ID,
    PAGE,
    ACTION,
    ORDER_TOTAL,
    SHIPPING_COST,
    TAX,
    ITEMS,
    PROMO_CODE,
    DISCOUNT_AMOUNT,
    NET_REVENUE
)

SELECT
    RAW_DATA:event_id::STRING,

    TO_TIMESTAMP_NTZ(
        RAW_DATA:timestamp::STRING
    ),

    RAW_DATA:user_id::NUMBER,

    RAW_DATA:page::STRING,

    RAW_DATA:action::STRING,

    COALESCE(
        RAW_DATA:order.total::NUMBER(18,2),
        0
    ),

    COALESCE(
        RAW_DATA:order.shipping_cost::NUMBER(18,2),
        0
    ),

    COALESCE(
        RAW_DATA:order.tax::NUMBER(18,2),
        0
    ),

    COALESCE(
        RAW_DATA:order.items::NUMBER,
        0
    ),

    RAW_DATA:promo_code::STRING,

    COALESCE(
        RAW_DATA:discount_amount::NUMBER(18,2),
        0
    ),

    CASE
        WHEN COALESCE(
            RAW_DATA:order.total::NUMBER(18,2),
            0
        ) > 0

        THEN
            RAW_DATA:order.total::NUMBER(18,2)

            - COALESCE(
                RAW_DATA:order.shipping_cost::NUMBER(18,2),
                0
            )

            - COALESCE(
                RAW_DATA:order.tax::NUMBER(18,2),
                0
            )

            - COALESCE(
                RAW_DATA:discount_amount::NUMBER(18,2),
                0
            )

        ELSE 0
    END

FROM LAKE_RAW_EVENTS;


CREATE OR REPLACE TABLE QUARANTINE_RAW_EVENTS (
    QUARANTINE_ID NUMBER AUTOINCREMENT,
    RAW_RECORD_TEXT VARCHAR,
    REASON VARCHAR,
    QUARANTINED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


INSERT INTO QUARANTINE_RAW_EVENTS (
    RAW_RECORD_TEXT,
    REASON
)

SELECT
    RAW_RECORD_TEXT,
    'MALFORMED_JSON_BODY'

FROM STAGE_RAW_EVENTS

WHERE TRY_PARSE_JSON(RAW_RECORD_TEXT) IS NULL;



SELECT COUNT(*) AS TOTAL_RAW_RECORD_CT
FROM LAKE_RAW_EVENTS;


SELECT
    COUNT(*) AS STORED_RECORDS_QTY,
    SUM(NET_REVENUE) AS TOTAL_NET_REVENUE
FROM DW_STRUCTURED_EVENTS;


SELECT
    QUARANTINE_ID,
    RAW_RECORD_TEXT,
    REASON
FROM QUARANTINE_RAW_EVENTS
ORDER BY QUARANTINE_ID;


SELECT
    (SELECT COUNT(*) FROM LAKE_RAW_EVENTS) AS LAKE_RECORDS,
    (SELECT COUNT(*) FROM DW_STRUCTURED_EVENTS) AS DW_RECORDS,
    (SELECT COUNT(*) FROM QUARANTINE_RAW_EVENTS) AS QUARANTINED_RECORDS,
    (SELECT SUM(NET_REVENUE) FROM DW_STRUCTURED_EVENTS) AS TOTAL_NET_REVENUE;
