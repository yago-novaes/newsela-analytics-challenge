# Newsela Analytics Engineering Challenge 

## Overview
Welcome to my submission for the Senior Analytics Engineering Take-Home Challenge. The goal was to analyze Stack Overflow public data to uncover engagement drivers, mimicking the complexity of handling large-scale educational data.

Below is a breakdown of my engineering process, from discovery to execution.

---

## 1. Discovery & Data Modeling
My first step was to deeply understand the dataset before writing any analytical logic. This prevents rework, avoids trying to reverse-engineer tables that are already aggregated, and significantly reduces costs by simplifying downstream queries.

### Schema Visualization
To ensure I understood the lineage and relationships, I extracted the schema metadata and built an Entity Relationship Diagram (ERD).
- **Tooling:** I queried `INFORMATION_SCHEMA`, used AI to convert the JSON output to DBML, and visualized it in `dbdiagram.io`.
- **Documentation:** I cross-referenced the BigQuery schema with the official [Stack Exchange Data Explorer documentation](https://data.stackexchange.com/help) to validate Foreign Keys and IDs.
- *Artifact:* Please check `methodology/schema_audit.png` to see the map I created.

---

## 2. Architectural Decisions & Performance
During the audit, I identified a critical opportunity for cost optimization (BigQuery Slot Time & Bytes Scanned):

* **Specialized Tables vs. Monolith:** Instead of querying the massive `stackoverflow_posts` monolithic table, I chose to utilize `posts_questions`.
* **Why?** It is semantically correct for the prompts, avoids scanning unnecessary columns, and leverages partitioning on `creation_date` more effectively.

---

## 3. SQL Style & Standards
I strictly adhered to modern Analytics Engineering code standards to ensure maintainability and clean Git diffs:
* **Formatting:** Lowercased keywords, 4-space indentation, and positional grouping (`GROUP BY 1, 2`).
* **Structure:** **CTE-First approach**. I treated early CTEs as a "Staging Layer" (cleaning, unnesting, filtering) so the final `SELECT` acts as a clean "Mart".

---

## 4. Technical Approach by Prompt

### Prompt 1: Tag Analysis
*File: `queries/01_tag_engagement_analysis.sql`*
* **Technique:** Array Handling.
* **Decision:** Instead of using `LIKE '%tag%'` (which is prone to false positives), I used `UNNEST(SPLIT(tags, '|'))`. This ensures mathematical precision when counting tag occurrences.

### Prompt 2: Python vs. dbt (YoY Growth)
*File: `queries/02_python_dbt_yoy_growth.sql`*
* **Technique:** Window Functions.
* **Decision:** I used `LAG()` to calculate Year-over-Year growth in a single pass. This avoids complex self-joins and keeps the query performant.
* **Filtering:** I applied strict equality (`tags = 'dbt'`) rather than wildcards to ensure we analyzed posts dedicated *only* to those topics, as requested.

### Prompt 3: Quality Drivers
*File: `queries/03_content_quality_drivers.sql`*
* **Technique:** Feature Engineering.
* **Decision:** I created classification buckets directly in SQL (e.g., Title Length, Body Length) to transform raw text data into analytical dimensions, proving that "User Effort" correlates with "Answer Quality."

---

## 5. Future Improvements (The "Staff" View)
If this were a production `dbt` project at Newsela, I would propose:

1.  **Incremental Models:** The `posts` table is huge and immutable. I’d set this up in dbt as an `incremental` model to only process new data since the last run.
2.  **Data Quality Tests:** I’d add `dbt test` to ensure `accepted_answer_id` actually exists in the answers table (Referential Integrity).
3.  **Governance:** Build a mapping table/seed to group synonyms (e.g., `react` and `reactjs`).

---

**Yago Novaes**