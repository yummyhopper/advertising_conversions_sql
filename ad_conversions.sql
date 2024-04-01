
/*

SQL Project: Advertising Conversions in SQL

ad_table
- ad_id: an unique ID for each ad.
- xyz_campaign_id: an ID associated with each ad campaign of XYZ company.
- fb_campaign_id: an ID associated with how Facebook tracks each campaign.
- Spent: Amount paid by company xyz to Facebook, to show that ad.

audience_table
- ad_id: an unique ID for each ad.
- age: age of the person to whom the ad is shown.
- gender: gender of the person to whim the add is shown
- interest: a code specifying the category to which the person’s interest belongs (interests are as mentioned in the person’s Facebook public profile).

impression_table
- ad_id: an unique ID for each ad.
- Impressions: the number of times the ad was shown.
- Clicks: number of clicks on for that ad.

conversion table
- ad_id: an unique ID for each ad.
- Total conversion: Total number of people who enquired about the product after seeing the ad.
- Approved conversion: Total number of people who bought the product after seeing the ad.


*/

CREATE DATABASE adconversions
use adconversions

/* Data Exploration and Cleaning */

SELECT COUNT(*) as Dupes
FROM ad_table
GROUP BY ad_id
HAVING Count(*) > 1

-- 0 Duplicate ad_ids

SELECT COUNT(DISTINCT xyz_campaign_id) as unique_campaigns
FROM ad_table

-- 3 unique xyz_campaign_ids

SELECT COUNT(DISTINCT fb_campaign_id) as unique_campaigns
FROM ad_table

-- 691 unique fb_campaign_ids

SELECT COUNT(DISTINCT fb_campaign_id) as unique_campaigns, xyz_campaign_id
FROM ad_table
GROUP BY xyz_campaign_id

-- 916: 47 unique campaigns
-- 936: 367 unique campaigns
-- 1178: 277 unique campaigns

SELECT COUNT(*) as Nulls
FROM ad_table
WHERE ad_id IS NULL OR xyz_campaign_id IS NULL OR fb_campaign_id IS NULL

-- 0 Nulls

/* KPIs */

-- CTR (Click-Through Rate = Clicks / Impressions * 100)

SELECT xyz_campaign_id, ROUND((SUM(CAST(Clicks AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 3) as Click_Through_Rate
FROM impression_table as i
JOIN ad_table as a on a.ad_id = i.ad_id
GROUP BY xyz_campaign_id
ORDER BY Click_Through_Rate DESC

-- 936: 0.024
-- 916: 0.023
-- 1178: 0.018

-- Total Conversion Rate (Total Conversions/Interactions * 100)

SELECT xyz_campaign_id, ROUND((SUM(CAST(Total_Conversion AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 3) as Conversion_Rate
FROM conversion_table as c
JOIN ad_table as a on a.ad_id = c.ad_id
JOIN impression_table as i on a.ad_id = i.ad_id
GROUP BY xyz_campaign_id
ORDER BY Conversion_Rate DESC

-- 916: 0.012
-- 936: 0.007
-- 1178: 0.001

-- Approved Conversion Rate

SELECT xyz_campaign_id, ROUND((SUM(CAST(Approved_Conversion AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 4) as Conversion_Rate
FROM conversion_table as c
JOIN ad_table as a on a.ad_id = c.ad_id
JOIN impression_table as i on a.ad_id = i.ad_id
GROUP BY xyz_campaign_id
ORDER BY Conversion_Rate DESC

-- 916: 0.005
-- 936: 0.0023
-- 1178: 0.0004

-- CPC (Cost Per Click = Spent / Clicks *100)

SELECT xyz_campaign_id, ROUND((SUM(CAST(Spent AS FLOAT)) / SUM(CAST(Clicks AS FLOAT))) * 100, 3) as Cost_Per_Click
FROM impression_table as i
JOIN ad_table as a on a.ad_id = i.ad_id
GROUP BY xyz_campaign_id
ORDER BY Cost_Per_Click DESC

-- 1178: 154.326
-- 936: 145.835
-- 916: 132.487

/* Demographic Analysis */ 

-- Which age groups had high/medium/low click-through-rates on each ad?

SELECT xyz_campaign_id, age,
    CASE
        WHEN Click_Through_Rate > 0.025 THEN 'Higher'
        WHEN Click_Through_Rate > 0.020 THEN 'Medium'
        ELSE 'Lower'
    END as CTR 
FROM (
    SELECT xyz_campaign_id, ROUND((SUM(CAST(Clicks AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 3) as Click_Through_Rate, age
    FROM impression_table as i
    JOIN ad_table as a on a.ad_id = i.ad_id
    JOIN audience_table as d on a.ad_id = d.ad_id
    GROUP BY xyz_campaign_id, age
) as subquery
ORDER BY xyz_campaign_id, age

-- Which genders were more and less likely to click on each ad?

DROP TABLE IF EXISTS #CTR
CREATE TABLE #CTR (
    campaign_id INT,
    gender NVARCHAR(10),
    CTR FLOAT,
    CPC FLOAT,
    TCR FLOAT,
    ACR FLOAT
)

INSERT INTO #CTR 
SELECT xyz_campaign_id, gender, 
ROUND((SUM(CAST(Clicks AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 3), 
ROUND((SUM(CAST(Spent AS FLOAT)) / SUM(CAST(Clicks AS FLOAT))) * 100, 3), 
ROUND((SUM(CAST(Total_Conversion AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 3), 
ROUND((SUM(CAST(Approved_Conversion AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 4)
FROM impression_table as i
JOIN ad_table as a on a.ad_id = i.ad_id
JOIN audience_table as d on a.ad_id = d.ad_id
JOIN conversion_table as c on a.ad_id = c.ad_id
GROUP BY xyz_campaign_id, gender

SELECT campaign_id, gender, CTR, AVG(CTR) OVER(Partition by campaign_id) as overall_CTR
FROM #CTR
ORDER BY campaign_id, gender

SELECT campaign_id, gender, CTR, CPC, TCR, ACR
FROM #CTR
ORDER BY campaign_id, gender

-- Which interests have high click-through-rates on each ad?

WITH interests AS (
    SELECT xyz_campaign_id, interest, ROUND((SUM(CAST(Clicks AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 3) as Click_Through_Rate
    FROM impression_table as i
    JOIN ad_table as a on a.ad_id = i.ad_id
    JOIN audience_table as d on a.ad_id = d.ad_id
    GROUP BY xyz_campaign_id, interest
)

SELECT xyz_campaign_id, interest, Click_Through_Rate
FROM interests
ORDER BY xyz_campaign_id, interest

/* Putting it all together */

-- Can we create a lookup procedure for evaluating all statistics of individual facebook ad campaigns accross all demographics?

DROP PROCEDURE IF EXISTS fb_campaign_lookup

GO

CREATE PROCEDURE fb_campaign_lookup

@campaign_id INT

AS

CREATE TABLE #fb_campaign (
    campaign_id INT,
    gender NVARCHAR(10),
    age NVARCHAR(10),
    interest INT,
    CTR FLOAT,
    CPC FLOAT,
    TCR FLOAT,
    ACR FLOAT
)

INSERT INTO #fb_campaign 
SELECT fb_campaign_id, gender, age, interest,
ROUND((SUM(CAST(Clicks AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 3), 
ROUND((SUM(CAST(Spent AS FLOAT)) / SUM(CAST(Clicks AS FLOAT))) * 100, 3), 
ROUND((SUM(CAST(Total_Conversion AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 3), 
ROUND((SUM(CAST(Approved_Conversion AS FLOAT)) / SUM(CAST(Impressions AS FLOAT))) * 100, 4)
FROM impression_table as i
JOIN ad_table as a on a.ad_id = i.ad_id
JOIN audience_table as d on a.ad_id = d.ad_id
JOIN conversion_table as c on a.ad_id = c.ad_id
WHERE fb_campaign_id = @campaign_id
GROUP BY fb_campaign_id, gender, age, interest

SELECT * FROM #fb_campaign

GO

EXEC fb_campaign_lookup @campaign_id = 103928