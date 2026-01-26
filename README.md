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

![Stack Overflow Schema](diagrams/stackoverflow-dbdiagram.png)

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
The queries adhere to the **dbt Labs SQL Style Guide**, the industry standard for Analytics Engineering, to facilitate Code Reviews and Git diff reading:
* **Keywords in lowercase:** Improves readability and consistency.
* **4-space indentation:** Standard alignment for nested logic.
* **CTEs (Common Table Expressions):** Used for modularity and readability (avoiding subqueries).
* **Explicit column names in `GROUP BY`:** Favored over positional numbers (e.g., `1, 2`) to ensure production robustness against schema changes.
* **In-line comments:** Explaining business decisions directly in the code.

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

### Q1: Tag Performance & Ecosystems
> **1. What tags on a Stack Overflow question lead to the most answers and the highest rate of approved answers for the current year? What tags lead to the least? How about combinations of tags?**

The analysis revealed a clear dichotomy between generalist languages and niche tools.

* **Highest Approval (Niche Specialists):** Tools focused on data manipulation lead the ranking. `awk` (**66.0%**), `dplyr` (**64.2%**), and `sed` (**61.8%**) have the highest success rates. These communities deal with objective problems ("input -> output"), facilitating definitive answers.
* **Least Approval (Environment Dependencies):** Tags related to external environments like `google-chrome-extension` (**12.9%**) and `browser` (**12.9%**) perform worst. These issues are often hard to reproduce ("it works on my machine"), leading to low engagement.
* **Combinations (Synergy):** While generic tags struggle, specific combinations like `python|pandas|dataframe` maintain a high **58.0%** approval rate even with massive volume (4.5k+ questions), indicating a highly mature documentation ecosystem compared to generic `python` (**35.0%**).

### Q2: Technology Lifecycle (Python vs. dbt)
> **2. For posts which are tagged with only ‘python’ or ‘dbt’, what is the year over year change of question-to-answer ratio for the last 10 years? How about the rate of approved answers on questions for the same time period? How do posts tagged with only ‘python’ compare to posts only tagged with ‘dbt’?**

We observed distinct stages of the technology adoption lifecycle:

* **Python (Saturation Phase):** Over the last decade, Python transitioned from niche to mass-market. As volume exploded, "attention per question" diluted drastically:
    * **2012:** 2.63 answers/question | **72.1%** approval rate.
    * **2022:** 1.26 answers/question | **35.4%** approval rate.
* **dbt (Adoption/Hype Phase):** Being a newer tool (data starts ~2020), dbt shows early volatility. The approval rate dropped from **41.9%** (2020) to **27.9%** (2022), suggesting a recent influx of beginners still learning to formulate good questions (the "Eternal September" effect).
* **Note on Data Scope:** adhering strictly to the prompt's requirement ("tagged with only python"), I excluded posts with combined tags (e.g., python|pandas). It is worth noting that this strict filtering isolates generic/beginner questions and excludes a significant portion of the specialized Python ecosystem, potentially influencing the approval rate comparison against dbt.


### Q3: Behavioral Quality Drivers
> **3. Other than tags, what qualities on a post correlate with the highest rate of answer and approved answer? Feel free to get creative.**

I applied **Feature Engineering** to measure cognitive friction and context. The data confirmed three critical behaviors:

* **Readability is King:** Questions without code formatting (`no code formatting`) are statistically fatal, with only **18.0%** approval on weekdays. The "Wall of Text" format is the biggest barrier to success.
* **Professionalism Pays Off:** Titles with a desperate tone (containing "URGENT", "HELP", "ASAP") correlate with a **24.4%** approval rate, significantly lower than the balanced/neutral "Sweet Spot" (**33.6%**).
* **The "Weekend Warrior" Effect:** Contrary to corporate intuition, questions posted on **weekends** achieve consistently higher success rates than weekdays. For example, "balanced" questions hit **35.4%** approval on weekends vs **33.6%** on weekdays. The data suggests a lower noise-to-signal ratio and higher availability of experts during off-hours.

---
## Technical Approach & Architectural Decisions

This section details the engineering decisions behind each query, focusing on performance optimization, maintainability, and cost reduction.

### Q1: Tag Analysis (Set Operations)

My approach focused on transforming semi-structured string data into analytical metrics through a multi-step pipeline:
1.  **Data Isolation (CTE):** First, I built the `post_questions` CTE to filter the raw table down to the specific date range and relevant columns immediately. This enforces "Predicate Pushdown," ensuring subsequent steps process only the necessary data.
2.  **Array Flattening:** Since tags are stored as pipe-separated strings (e.g., `python|pandas`), I used `UNNEST(SPLIT())` in the `flat_tag` CTE. This normalization step transforms the 1:N relationship into 1:1 rows, allowing for precise individual tag aggregation.
3.  **Dual Aggregation Strategy:** I created two parallel analysis paths:
    * *Individual Tags:* Aggregated the flattened data to rank tags by volume and approval rate.
    * *Combinations:* Queried the raw string patterns (without unnesting) to identify "tech stacks" that work well together (e.g., `python|pandas|dataframe`).
4.  **Unified Output:** Finally, I used `UNION ALL` to stitch together four distinct analytical views (Volume, High Quality, Low Quality, Combinations) into a single report, simplifying the consumption layer.

* **Optimization (Block Pruning):** I prioritized `creation_date BETWEEN 'start' AND 'end'` over `EXTRACT(YEAR from creation_date) = 2022`. Even on non-partitioned tables, this syntax allows BigQuery to leverage metadata caching and potential clustering (**Block Pruning**), whereas wrapping a column in a function (`EXTRACT`) forces a full column scan.

* **Unified Reporting:** Instead of running separate queries, I utilized `UNION ALL` to consolidate all analytical perspectives (Most Answered, Highest Approval, Least Approval, Combinations) into a single result set. This reduces the overhead of establishing multiple connections and simplifies the consumption layer (Dashboard/CSV).
**Engineering Trade-off (Performance vs. DRY):** I initially explored a DRY (Don't Repeat Yourself) approach using Window Functions to generate all rankings in a single pass. However, benchmarking revealed that for this specific dataset size, the overhead of sorting (CPU intensive) outweighed the cost of multiple columnar scans (I/O intensive). The UNION ALL approach proved to be 14x more efficient in slot time usage (13s vs 181s), leading me to prioritize execution efficiency over syntactic elegance.

* **Noise Reduction:** Applied a strict `HAVING total_questions > 1000` filter to ensure statistical significance, filtering out "long-tail" tags that would skew the quality analysis.

### Q2: YoY Trends (Defensive SQL)

To analyze trends over time without complex self-joins, I relied on window functions:
1.  **Scoped Filtering:** I started by filtering the dataset strictly for 'python' and 'dbt' tags. This removes noise early and creates a clean baseline for comparison.
2.  **Annual Bucketing:** I aggregated the metrics by `year` and `tag` to establish the base performance indicators (Question-to-Answer Ratio and Approval Rate).
3.  **Growth Calculation (LAG):** Instead of joining the table to itself to compare years (which is expensive), I used the `LAG()` window function partitioned by tag and ordered by year. This allows the query to efficiently "look back" at the previous row (`year - 1`) to calculate the Year-Over-Year percentage change dynamically.

* **Dynamic Time Windows:** Implemented `DECLARE` variables for the target year. In a production environment (dbt), these would be replaced by `{{ var('target_year') }}`, allowing the model to run incrementally without code changes.

* **Defensive Aggregation:** I enforced explicit column names in the `GROUP BY` clause (`group by post_year, tag`) instead of positional references (`group by 1, 2`). While positional grouping is faster to write, it is fragile in production pipelines if the `SELECT` clause order changes.

* **Metric Integrity:** Handled the "First Year" problem in Year-Over-Year (YoY) calculations using `NULLIF` and logic to return `null` instead of `0`. Returning `0` for the first year would be mathematically incorrect (implying 0% growth rather than undefined growth).

### Q3: Quality Drivers (Feature Engineering)

For this analysis, I shifted from a pure data perspective to a **Product/UX mindset**. I asked myself: *"As a Stack Overflow user, what friction points prevent me from answering a question?"*

This led to a hypothesis-driven approach rather than just querying available columns:

1.  **Hypothesis Generation:**
    * *Is it too long?* (Body length friction)
    * *Is it a "wall of text"?* (Readability/No code blocks)
    * *Is the title desperate?* (Unprofessional tone like "URGENT", "HELP")
    * *Did I miss it?* (Posting time/Visibility)

2.  **Architectural Decision (Cost & Performance):**
    * I deliberately opted **not** to join `posts_questions` with `posts_answers`.
    * **Reasoning:** Joining a question to its answers causes **row fan-out** (1 question -> N answers). This would inflate compute costs and require complex re-aggregation without adding value to the analysis of the *question's* structural quality. I focused strictly on the "input" (the question) to predict the "output" (success metrics).

3.  **Scope Definition (Discarded Hypotheses):**
    * I discarded the hypothesis "Is the question too difficult?" because measuring technical difficulty is subjective and would require NLP/Text Analysis, which is out of scope for a pure SQL approach.

4.  **Feature Pools:**
    To simplify the analysis, I grouped the hypotheses into two distinct buckets:
    * **Pool 1: Cognitive Load & Readability (Effort Friction):** Combined factors like Body Length, formatting (presence of `<code>` tags), and Title Quality.
    * **Pool 2: Availability (Context):** Isolated the `Day of Week` to test the visibility hypothesis (Weekend vs. Weekday).

---

## Future Improvements

1.  **Partitioning & Clustering:** The current `posts_questions` table is not partitioned. In a production scenario, I would create a derived table partitioned by `creation_date` and clustered by `tags` to drastically reduce scan costs.
2.  **dbt Project:** Migrate raw SQL queries to dbt models, allowing for automatic testing (`schema tests`, `custom tests`) and static documentation generation.
3.  **CI/CD:** Implement a deployment pipeline to validate changes in business queries before merging into the `main` branch.

---
**Author:** Yago Novaes Neves