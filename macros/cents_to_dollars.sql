{#
  CONCEPT: a macro is a reusable Jinja function that RETURNS SQL TEXT.
  dbt replaces {{ cents_to_dollars('unit_price_cents') }} with the SQL below at
  compile time, so look in target/compiled/ to see what Snowflake actually ran.
  Use macros for logic that genuinely repeats; one-off logic stays in the model.
#}
{% macro cents_to_dollars(column_name, precision=2) %}
    round(({{ column_name }})::number(18, 0) / 100, {{ precision }})
{% endmacro %}
