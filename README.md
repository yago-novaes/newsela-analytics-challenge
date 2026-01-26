# Stack Overflow Analytics: BigQuery Public Dataset

This project consists of an exploratory and structural analysis of the Stack Overflow public dataset available on Google BigQuery. The goal is to answer business questions regarding community engagement, technology trends (Python vs. dbt), and post quality drivers, applying modern **Analytics Engineering** practices.

## Logical Reasoning & Methodology

Before writing a single line of business SQL, I adopted a **"Schema First"** approach. Understanding the dataset beforehand prevents rework, avoids unnecessary reverse engineering on already aggregated tables, and reduces costs by simplifying queries.

### 1. Discovery & Modeling
To optimize the time spent understanding the data model:
1.  I executed scripts on `INFORMATION_SCHEMA` to extract table metadata.
2.  I used AI to convert the schema JSON output into **DBML**.
3.  I generated the Entity-Relationship Diagram (ERD) using **dbdiagram.io**.

This reinforces the importance of documentation, lineage, and well-maintained catalogs. Visualizing the diagram allowed me to quickly identify keys and relationships.

![Stack Overflow Schema](diagrams/stackoverflow-dbdiagram.jpg)

### 2. Architectural Analysis: OLTP vs. OLAP
To ensure JOIN integrity, I consulted the [official Stack Exchange Data Explorer (SEDE) documentation](https://meta.stackexchange.com/questions/2677/database-schema-documentation-for-the-public-data-dump-and-sede/2678#2678).

I identified a clear paradigm shift between the original database and BigQuery:
* **Original (SEDE - SQL Server):** 3rd Normal Form (3NF) modeling, optimized for transactions (OLTP). The `Posts` table is unified, using a `PostTypeId` discriminator.
* **BigQuery (Analytical):** Transformed into an OLAP model. The `Posts` table was "sharded" into physical tables based on type (`posts_questions`, `posts_answers`, etc.).

**Architectural Decision:** This fragmentation facilitates analytical queries. I opted to focus the study on the `posts_questions` table to avoid unnecessary *fan-out* when joining with answers, focusing instead on the intrinsic qualities of the question itself.

### 3. Data Quality & Profiling
I performed data quality tests (`src/2_data_profiling/check_integrity_post_questions.sql`) prior to coding business rules. My goal is to not solve problems that don't exist.
* **PK Integrity:** Validated the uniqueness and non-nullability of IDs.
* **Tag Formatting:** Checked for "dirty" tags (e.g., `|dbt|` vs `dbt`).
    * *Result:* The dataset is already clean (only `tag` or `tag1|tag2`).
    * *Impact:* I avoided the unnecessary use of expensive functions like `REGEXP_REPLACE` or `TRIM` inside loops, saving **slot time** in BigQuery.

### 4. Code Standards
The queries follow a strict style guide to facilitate Code Reviews and Git diff reading:
* Keywords in **lowercase**.
* 4-space indentation.
* Use of CTEs (Common Table Expressions) for modularity.
* Explicit column names in `GROUP BY` (instead of positional numbers) for production robustness.
* In-line comments explaining business decisions.

---

## Project Structure

```text
.
├── README.md                                # Project documentation
├── diagrams/
│   ├── stackoverflow-dbdiagram.jpg          # Entity-Relationship Diagram (ERD) image
│   └── schemas-db-stackeroverflow.json      # DBML/JSON Schema definition
├── src/
│   ├── 1_schema_extraction/
│   │   └── information_schema.sql           # Script to extract metadata from BigQuery
│   ├── 2_data_profiling/
│   │   ├── check_integrity_post_questions.sql # PK and data quality validation
│   │   └── recreate_partition.sql           # (Conceptual) DDL for partitioning strategy
│   └── 3_business_queries/
│       ├── 01_tag_analysis.sql              # Q1: Tag volume & approval rates
│       ├── 02_python_vs_dbt_yoy.sql         # Q2: YoY Trends Analysis
│       └── 03_answer_quality_drivers.sql    # Q3: Quality & Behavioral Analysis
└── output/
    ├── 01_tag_analysis.csv                  # Result dataset for Q1
    ├── 02_python_vs_dbt_yoy.csv             # Result dataset for Q2
    └── 03_answer_quality_drivers.csv        # Result dataset for Q3

```

---

## Results & Insights (Data Analysis)

### Q1: Specialists vs. Generalists (Tag Analysis)
*Which tags lead to the most answers and what is the approval rate for the current year?*

The analysis revealed a clear dichotomy between generalist languages and niche tools.

* **High Approval (Niche):** Text/data manipulation tools like `awk` (**66%**), `dplyr` (**64%**), and `sed` (**61%**) lead the quality ranking.
    * *Insight:* Questions in these communities tend to be objective ("how to transform X into Y"), facilitating definitive, approved answers.
* **Low Approval (Environment):** Tags related to external environments like `google-chrome-extension` (**12.8%**) and `browser` (**12.9%**) have the worst rates.
    * *Insight:* Hard-to-reproduce problems ("it works on my machine") generate low resolutive engagement.
* **The Power of the Python Ecosystem:** The combination `python|pandas|dataframe` maintains an impressive **57%** approval rate even with high volume, indicating an extremely healthy and well-documented community.

### Q2: Python Saturation & The Rise of dbt
*Comparative analysis of maturity and trends (YoY).*

We observed the classic technology adoption lifecycle:

* **Python (Saturation):** Over 10 years, the ecosystem exploded in volume, but "attention" metrics dropped drastically.
    * **2012:** Average of **2.63** answers/question and **72%** approval.
    * **2022:** Average of **1.26** answers/question and **35%** approval.
* **dbt (Early Adoption):** Incipient data (starting in 2020) shows the "hype cycle." The approval rate dropped from **41%** (2020) to **27%** (2022), suggesting a massive influx of beginners still learning how to formulate good questions about the tool.

### Q3: Developer Psychology (Quality Drivers)
*What makes a question get answered, other than the topic?*

I applied **Feature Engineering** to measure cognitive friction and context. The data confirmed three critical behaviors:

1.  **The "Wall of Text" is Fatal:** Questions without code formatting (`no code formatting`) have the worst performance in the entire dataset: only **17.9%** approval.
2.  **Professionalism Pays Off:** Titles with a desperate tone (containing "URGENT", "HELP", "ASAP") have a **24%** approval rate, significantly lower than the balanced "Sweet Spot" (**33-35%**).
3.  **The "Weekend Warrior" Effect:** In **all** analyzed categories, questions posted on weekends achieve higher success rates than those posted on weekdays (e.g., **35.4%** vs **33.5%** for balanced questions).
    * *Hypothesis:* Lower noise (volume) and higher time availability from experts during weekends.

---

## Future Improvements

1.  **Partitioning & Clustering:** The current `posts_questions` table is not partitioned. In a production scenario, I would create a derived table partitioned by `creation_date` and clustered by `tags` to drastically reduce scan costs.
2.  **dbt Project:** Migrate raw SQL queries to dbt models, allowing for automatic testing (`schema tests`, `custom tests`) and static documentation generation.
3.  **CI/CD:** Implement a deployment pipeline to validate changes in business queries before merging into the `main` branch.

---
**Author:** Yago Novaes Neves