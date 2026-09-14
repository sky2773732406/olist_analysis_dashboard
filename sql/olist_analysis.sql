-- 总体 KPI：GMV、订单数、客单价
SELECT
	ROUND(SUM(oi.price + oi.freight_value),2) AS gmv,
	COUNT(DISTINCT o.order_id) AS total_order,
	ROUND(SUM(oi.price + oi.freight_value) / COUNT(distinct o.order_id),2) AS aov
FROM
	orders AS o
JOIN
	order_items AS oi 
ON
	o.order_id = oi.order_id
WHERE
	o.order_status = 'delivered';

-- 月度销售趋势 + 环比（MoM%）
WITH monthly AS (
SELECT 
	DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m') AS month,
	COUNT(DISTINCT o.order_id) AS orders,
	SUM(oi.price + oi.freight_value) AS gmv
FROM
	orders AS o
JOIN
	order_items AS oi
ON
	o.order_id = oi.order_id
WHERE
	o.order_status = 'delivered'
GROUP BY
	month
)
SELECT
	month,
	orders,
	ROUND(gmv,2) AS gmv,
	ROUND((gmv - LAG(gmv)OVER(ORDER BY month)) / LAG(gmv)OVER(ORDER BY month) * 100,2) AS mom_pct
FROM
	monthly
ORDER BY
	month;

-- 累计 GMV（running total）
WITH monthly AS (
SELECT 
	DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m') AS month,
	COUNT(DISTINCT o.order_id) AS orders,
	SUM(oi.price + oi.freight_value) AS gmv
FROM
	orders AS o
JOIN
	order_items AS oi
ON
	o.order_id = oi.order_id
WHERE
	o.order_status = 'delivered'
GROUP BY
	month
)
SELECT
	month,
	ROUND(gmv,2) AS gmv,
	ROUND(SUM(gmv)OVER(ORDER BY month),2) AS cumulative_gmv
FROM
	monthly
GROUP BY
	month;
	
-- 品类 Top10（按 GMV）
SELECT
	COALESCE(t.product_category_name_english,p.product_category_name,'unknown') AS category,
	COUNT(DISTINCT o.order_id) AS orders,
	ROUND(SUM(oi.price + oi.freight_value),2) AS gmv
FROM
	orders AS o
JOIN
	order_items AS oi
ON
	o.order_id = oi.order_id
LEFT JOIN
	products AS p
ON
	oi.product_id = p.product_id
LEFT JOIN
	product_category_translation AS t
ON
	p.product_category_name = t.product_category_name
WHERE
	o.order_status = 'delivered'
GROUP BY
	category
ORDER BY
	gmv DESC
LIMIT 10;

-- 帕累托：品类累计贡献
WITH cat AS (
  SELECT
    COALESCE(t.product_category_name_english, NULLIF(p.product_category_name, ''), 'unknown') AS category,
    SUM(oi.price + oi.freight_value) AS gmv
  FROM 
		orders AS o
  JOIN 
		order_items AS oi 
	ON 
		o.order_id = oi.order_id
  LEFT JOIN 
		products AS p 
	ON 
		oi.product_id = p.product_id
  LEFT JOIN 
		product_category_translation AS t 
	ON 
		p.product_category_name = t.product_category_name
  WHERE 
		o.order_status = 'delivered'
  GROUP BY 
		category
),
ranked AS (
  SELECT
    category,
    gmv,
    ROW_NUMBER() OVER (ORDER BY gmv DESC) AS rn,
    SUM(gmv) OVER (ORDER BY gmv DESC)     AS cum_gmv,
    SUM(gmv) OVER ()                       AS total_gmv
  FROM 
		cat
)
SELECT
  rn,
  category,
  ROUND(gmv, 2)                          AS gmv,
  ROUND(cum_gmv / total_gmv * 100, 2)    AS cum_share_pct
FROM 
	ranked
ORDER BY 
	rn;

-- 州销售排行 + 占比
WITH state_sales AS (
  SELECT
    c.customer_state AS state,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(oi.price + oi.freight_value) AS gmv
  FROM 
		orders AS o
  JOIN 
		order_items AS oi 
	ON 
		o.order_id = oi.order_id
  JOIN 
		customers AS c 
	ON 
		o.customer_id = c.customer_id
  WHERE 
		o.order_status = 'delivered'
  GROUP BY 
		c.customer_state
)
SELECT
  state,
  orders,
  ROUND(gmv, 2) AS gmv,
  ROUND(gmv / SUM(gmv) OVER () * 100, 2) AS share_pct
FROM 
	state_sales
ORDER BY 
	gmv DESC;

-- RFM 用户分层
WITH snapshot AS (
  SELECT 
		DATE_ADD(MAX(order_purchase_timestamp), INTERVAL 1 DAY) AS d
  FROM 
		orders 
	WHERE 
		order_status = 'delivered'
),
cust AS (
  SELECT
    c.customer_unique_id,
    MAX(o.order_purchase_timestamp)  AS last_order,
    COUNT(DISTINCT o.order_id) AS frequency,
    SUM(oi.price + oi.freight_value) AS monetary
  FROM 
		orders AS o
  JOIN 
		customers AS c 
	ON 
		o.customer_id = c.customer_id
  JOIN 
		order_items AS oi 
	ON 
		o.order_id = oi.order_id
  WHERE
		o.order_status = 'delivered'
  GROUP BY 
		c.customer_unique_id
),
rfm AS (
  SELECT
    customer_unique_id,
    DATEDIFF((SELECT d FROM snapshot), last_order) AS recency,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY DATEDIFF((SELECT d FROM snapshot), last_order) DESC) AS r_score,
    NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC)  AS m_score
  FROM 
		cust
)
SELECT
  CONCAT(r_score, f_score, m_score) AS rfm_segment,
  COUNT(*) AS customers,
  ROUND(AVG(recency), 0) AS avg_recency_days,
  ROUND(AVG(frequency), 2) AS avg_frequency,
  ROUND(AVG(monetary), 2) AS avg_monetary,
  ROUND(SUM(monetary), 2) AS total_gmv
FROM 
	rfm
GROUP BY 
	rfm_segment
ORDER BY 
	customers DESC;

-- 复购率
WITH cust_freq AS (
  SELECT 
		c.customer_unique_id, 
		COUNT(DISTINCT o.order_id) AS freq
  FROM 
		orders AS o
  JOIN 
		customers AS c 
	ON 
		o.customer_id = c.customer_id
  WHERE 
		o.order_status = 'delivered'
  GROUP BY 
		c.customer_unique_id
)
SELECT
  COUNT(*) AS total_customers,
  SUM(freq >= 2) AS repeat_customers,
  ROUND(SUM(freq >= 2) / COUNT(*) * 100, 2) AS repeat_rate_pct
FROM 
	cust_freq;

-- 下单次数分布
WITH cust_freq AS (
  SELECT 
		c.customer_unique_id, 
		COUNT(DISTINCT o.order_id) AS freq
  FROM 
		orders AS o
  JOIN 
		customers AS c 
	ON 
		o.customer_id = c.customer_id
  WHERE 
		o.order_status = 'delivered'
  GROUP BY 
		c.customer_unique_id
)
SELECT
  freq AS order_count,
  COUNT(*) AS customers,
  ROUND(COUNT(*) / (SELECT COUNT(*) FROM cust_freq) * 100, 2) AS share_pct
FROM 
	cust_freq
GROUP BY 
	freq
ORDER BY 
	freq;

-- 配送天数 vs 评分
WITH ord AS (
  SELECT 
		order_id,
		DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) AS delivery_days
  FROM 
		orders
  WHERE 
		order_status = 'delivered' 
	AND 
		order_delivered_customer_date IS NOT NULL
),
rev AS (
  SELECT 
		order_id, 
		AVG(review_score) AS review_score
  FROM 
		order_reviews 
	GROUP BY 
		order_id
)
SELECT
  CASE
    WHEN o.delivery_days <= 5  THEN '0-5'
    WHEN o.delivery_days <= 10 THEN '6-10'
    WHEN o.delivery_days <= 15 THEN '11-15'
    WHEN o.delivery_days <= 20 THEN '16-20'
    WHEN o.delivery_days <= 30 THEN '21-30'
    ELSE '>30'
  END AS delivery_bucket,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(AVG(o.delivery_days), 1) AS avg_days,
  ROUND(AVG(r.review_score), 3)  AS avg_review_score
FROM 
	ord AS o
JOIN 
	rev AS r 
ON 
	o.order_id = r.order_id
GROUP BY 
	delivery_bucket
ORDER BY 
	avg_days;

-- 准时率 vs 评分
WITH ord AS (
  SELECT 
		order_id,
  CASE 
	WHEN order_delivered_customer_date <= order_estimated_delivery_date
  THEN 'on_time' 
	ELSE 'late' 
	END 
	AS delivery_status
  FROM 
		orders
  WHERE 
		order_status = 'delivered'
  AND 
		order_delivered_customer_date IS NOT NULL
  AND 
		order_estimated_delivery_date IS NOT NULL
),
rev AS (
  SELECT 
		order_id, 
		AVG(review_score) AS review_score
  FROM 
		order_reviews 
	GROUP BY 
		order_id
)
SELECT
  o.delivery_status AS status,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(AVG(r.review_score), 3) AS avg_review_score,
  ROUND(SUM(r.review_score <= 2) / COUNT(DISTINCT o.order_id) * 100, 2) AS bad_review_rate_pct
FROM 
	ord AS o
JOIN 
	rev AS r 
ON 
	o.order_id = r.order_id
GROUP BY 
	o.delivery_status;

-- 支付方式分布
SELECT
  payment_type,
  COUNT(DISTINCT order_id) AS orders,
  ROUND(SUM(payment_value), 2) AS payment_value,
  ROUND(SUM(payment_value)
        / (SELECT SUM(payment_value) FROM order_payments) * 100, 2) AS share_pct,
  ROUND(AVG(payment_installments), 2) AS avg_installments
FROM 
	order_payments
GROUP BY 
	payment_type
ORDER BY 
	payment_value DESC;
	
-- 评价分布
SELECT
  review_score,
  COUNT(*) AS reviews,
  ROUND(COUNT(*) / (SELECT COUNT(*) FROM order_reviews) * 100, 2) AS share_pct
FROM 
	order_reviews
GROUP BY 
	review_score
ORDER BY 
	review_score;

-- Top10 卖家（按 GMV）
SELECT
  oi.seller_id,
  s.seller_state,
  COUNT(DISTINCT oi.order_id) AS orders,
  ROUND(SUM(oi.price + oi.freight_value), 2) AS gmv
FROM 
order_items oi
JOIN 
	orders AS o  
ON 
	oi.order_id = o.order_id
JOIN 
	sellers AS s 
ON 
	oi.seller_id = s.seller_id
WHERE 
	o.order_status = 'delivered'
GROUP BY 
	oi.seller_id, s.seller_state
ORDER BY 
	gmv DESC
LIMIT 10;

-- 月度新增客户（按首次送达订单月份）
WITH first_order AS (
  SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_purchase
  FROM 
		orders AS o
  JOIN 
		customers AS c 
	ON 
		o.customer_id = c.customer_id
  WHERE 
		o.order_status = 'delivered'
  GROUP BY 
		c.customer_unique_id
)
SELECT
  DATE_FORMAT(first_purchase, '%Y-%m') AS month,
  COUNT(*) AS new_customers
FROM 
	first_order
GROUP BY 
	month
ORDER BY 
	month;