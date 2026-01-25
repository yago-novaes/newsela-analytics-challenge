# Newsela Analytics Engineering Challenge 🚀

## Overview
This repository contains the solution for the Senior Analytics Engineering Take-Home Challenge. The goal was to analyze Stack Overflow public data to uncover engagement drivers and community trends, mimicking the complexity of handling large-scale educational data.

## 🏗 Engineering Approach & Architecture
As an Analytics Engineer, my focus went beyond writing SQL. I structured this solution to be **scalable**, **cost-efficient**, and **maintainable**.

### 1. Data Discovery & Schema Audit
Before querying, I mapped the `bigquery-public-data` schema to understand relationships (Foreign Keys) and grain.
- **Decision:** I identified that `posts_questions` is a partitioned table containing pre-aggregated metrics (`answer_count`, `tags`).
- **Impact:** By using `posts_questions` instead of joining the monolithic `stackoverflow_posts` table, I reduced query costs (bytes scanned) and improved performance by avoiding unnecessary shuffles.
- *Artifact:* See `methodology/schema_audit.png`.

### 2. Code Quality & Style
- **Readability:** All queries follow strict SQL style guidelines (lowercased, 4-space indentation, CTE-first approach).
- **Modularity:** Common logic (like defining the "Current Year" or normalizing tags) is isolated in CTEs, mimicking `dbt` models (staging/intermediate layers).
- **Performance:**
    - Utilized `UNNEST` for array handling instead of `LIKE` wildcards to ensure accuracy.
    - Applied strict filtering (`creation_date`) early in the CTEs to leverage BigQuery partitioning.

---

## 📊 Key Findings (Prompt Responses)

### Prompt 1: Engagement by Tags
*Objective: Identify high-engagement topics for the current year.*
- **Findings:** Niche technical tags often show higher "Accepted Answer Rates" than broad tags like `python` or `javascript`, suggesting that specialized communities are more rigorous/helpful.
- **Query:** `queries/01_tag_engagement_analysis.sql`

### Prompt 2: Python vs. dbt Ecosystem (YoY Growth)
*Objective: Compare established vs. emerging tech trends.*
- **Methodology:** Used Window Functions (`LAG`) to calculate Year-over-Year growth dynamically.
- **Nuance:** I applied strict filtering (`tags = 'dbt'`) rather than wildcard matching to avoid polluting the analysis with multi-tag posts.
- **Insight:** While Python has volume, dbt shows the volatility and rapid growth characteristic of an emerging standard in the Modern Data Stack.
- **Query:** `queries/02_python_dbt_yoy_growth.sql`

### Prompt 3: Quality Drivers (Beyond Tags)
*Objective: Uncover what makes a "good" question.*
- **Feature Engineering:** I created buckets for `Title Length` and `Body Length` to proxy for "User Effort".
- **Insight:** There is a "Goldilocks Zone" for question length. Questions that are too short (<20 chars) or too long often receive fewer answers, correlating with the cognitive load required to answer them.
- **Query:** `queries/03_content_quality_drivers.sql`

---

## 🚀 Future Improvements (The "Staff" View)
If this were a production `dbt` project at Newsela, I would propose:

1.  **Incremental Models:** The `posts_questions` table is immutable/append-heavy. Implementing `incremental` materialization on `creation_date` would drastically reduce warehouse costs.
2.  **Data Tests:** Adding `dbt test` (unique, not_null) on primary keys and `accepted_values` on tags would prevent regression.
3.  **Integration with Schoolytics Strategy:** Just as we analyze Stack Overflow engagement, this logic of "Engagement Drivers" could be applied to Newsela's student data—correlating "Time on Task" (Body Length) with "Quiz Scores" (Accepted Answers) to give teachers better actionable insights.

---

*Author: Yago Novaes Neves*