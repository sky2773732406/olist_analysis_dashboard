# Olist 电商销售与用户复购分析看板

## 项目背景

基于 Olist 巴西电商公开数据集，完成从数据清洗、SQL 分析到 Power BI 可视化的完整数据分析项目。项目围绕销售趋势、品类贡献、地区表现、用户复购、配送体验和支付方式展开，最终交付一个可交互仪表板和一份分析报告。

## 数据源

- Brazilian E-Commerce Public Dataset by Olist
- 核心表：
  - orders：订单主表
  - order_items：订单商品明细
  - customers：客户表
  - products：产品表
  - product_category_name_translation：品类翻译表
  - order_payments：支付表
  - order_reviews：评价表
  - sellers：卖家表

## 技术栈

- Excel：数据清洗、VLOOKUP/XLOOKUP、数据透视表
- SQL：MySQL 8.0，JOIN、GROUP BY、CTE、窗口函数
- Power BI：数据建模、DAX、交互式仪表板
- Git：版本管理，提交信息只描述项目动作

## 分析问题

1. 每月 GMV、订单量、客单价趋势如何？
2. 哪些品类贡献最大？是否符合帕累托法则？
3. 哪些州/地区销售最好？
4. 用户复购率如何？RFM 分层后哪些是高价值用户？
5. 配送时间是否影响评分？差评集中在哪些环节？
6. 支付方式偏好是什么？

## 仓库结构

```text
olist-data-analysis/
├─ README.md
├─ .gitignore
├─ excel/
│  └─ olist_cleaning_pivot.xlsx
├─ sql/
│  └─ olist_analysis.sql
├─ powerbi/
│  └─ olist_dashboard.pbix
├─ report/
│  └─ analysis_report.md
└─ images/
   ├─ dashboard.png
   └─ olist_dashboard.pdf
```

## 复现步骤

### 1. 数据准备

将原始 CSV 放入本地 `archive/` 目录（Kaggle 下载解压后的默认名，已在 `.gitignore` 忽略）。大文件不提交到 Git。

### 2. Excel 清洗与透视

- 清洗 orders、order_items、customers、products、translation。
- 用 VLOOKUP/XLOOKUP 合并订单、客户、产品、品类。
- 新增 `item_total = price + freight_value`。
- 新增 `delivery_days = order_delivered_customer_date - order_purchase_timestamp`。
- 建立数据透视表：
  - 月度销售额
  - 品类 Top10
  - 州销售排行
  - 平均配送天数
- 输出：`excel/olist_cleaning_pivot.xlsx`

### 3. SQL 分析

将核心表导入 MySQL，编写以下查询：

- 总 GMV、订单数、客单价
- 月度销售趋势
- 环比增长
- 品类 Top10
- 州销售排行
- RFM 用户分层
- 复购率
- 配送天数与评分关系
- 帕累托品类贡献
- 支付方式分布

输出：`sql/olist_analysis.sql`

### 4. Power BI 仪表板

建立关系：

- orders[order_id] → order_items[order_id]
- orders[order_id] → payments[order_id]
- orders[order_id] → reviews[order_id]
- orders[customer_id] → customers[customer_id]
- order_items[product_id] → products[product_id]
- products[product_category_name] → translation[product_category_name]

创建日期表，编写 DAX：

- Total GMV
- Total Orders
- AOV
- MoM%
- YoY%
- Avg Delivery Days
- Bad Review Rate
- Repeat Users
- Repeat Rate

仪表板页面：

1. 总览 KPI
2. 销售趋势
3. 品类与地区
4. 用户复购与 RFM
5. 配送与评价
6. 支付方式

输出：`powerbi/olist_dashboard.pbix`

### 5. 报告与截图

- 将仪表板截图放入 `images/dashboard.png`
- 将分析结论写入 `report/analysis_report.md`
- README 中补充核心结论

## 核心结论

基于 Olist 已送达订单（96,478 单，总 GMV R$15,419,773.75）的实际计算：

- **销售趋势**：GMV 稳步上升，2017-11 达峰值 R$1,153,364.20（环比 +53.55%）；2018 年月均稳定在 R$100 万以上。
- **品类贡献**：Top10 品类贡献 **62.38%** GMV，18 个品类覆盖 80%，符合帕累托法则。头部为 health_beauty、watches_gifts、bed_bath_table。
- **地区表现**：**SP 州销售最高**，占 37.42%；SP + RJ + MG 合计 62.55%。
- **用户复购**：复购率仅 **3.0%**（93,358 名客户中 2,801 人复购），平台以拉新驱动为主。
- **配送与评分**：配送天数越长评分越低，相关系数 **-0.334**；>30 天平均仅 2.20 分，延迟订单差评率 53.99%。
- **支付方式**：信用卡占金额 **78.34%**，boleto 17.92%。

完整分析见 [report/analysis_report.md](report/analysis_report.md)。

## Git 提交规范

提交信息只描述项目动作，例如：

- `init project with readme and gitignore`
- `add excel cleaning and pivot analysis`
- `add sql queries for sales analysis`
- `add power bi dashboard and dax measures`
- `add analysis report and screenshots`

不提交本地计划、个人材料、原始大文件、临时文件。

## 说明

本仓库只包含项目相关文件。
