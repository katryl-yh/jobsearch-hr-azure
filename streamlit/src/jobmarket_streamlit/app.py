from pathlib import Path
import duckdb
import streamlit as st
from jobmarket_streamlit.connect_data_warehouse import get_db_connection

MART_FOR_OCCUPATION_FIELDS = "mart_occupation_demand"
_OPTION_LABEL_ALL = "All"  # for use with widgets

# -- setup streamlit pages

st.set_page_config(page_title="Job Market Analytics Dashboard", page_icon="📊", layout="wide")

pages = {
    "": [st.Page("pages/homepage.py", title="Home", icon="🏠")],
    "Analysis": [
        st.Page("pages/page_demand.py", title="Demand Overview", icon="📈"),
        st.Page("pages/page_employer.py", title="Employer Overview", icon="🏢"),
        st.Page("pages/page_geography.py", title="Urgency by Region", icon="🌍"),
    ],
}

# -- get available occupation fields for widget

# con = get_db_connection([MART_FOR_OCCUPATION_FIELDS])
db_path = str(Path(__file__).parents[3] / "data/job_ads.duckdb")
con = duckdb.connect(db_path, read_only=True)

rel_occupation_fields = con.sql(
    query=f"""
SELECT occupation_field
FROM marts.{MART_FOR_OCCUPATION_FIELDS}
GROUP BY 1
ORDER BY 1 DESC;
"""
)

available_occupation_fields = [item for (item,) in rel_occupation_fields.fetchall()]

con.close()
# -- sidebar selectbox filter

st.sidebar.selectbox(
    "Filter by **Occupation field**",
    [
        _OPTION_LABEL_ALL,
        *available_occupation_fields,
    ],
    key="occupation_field_filter",
)

# -- run!

pg = st.navigation(pages)
pg.run()
