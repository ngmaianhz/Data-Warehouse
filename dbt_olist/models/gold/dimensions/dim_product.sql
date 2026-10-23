SELECT 
    p.product_id,
    COALESCE(p.product_category_name, 'unknown') AS product_category_name_portuguese,
    COALESCE(t.product_category_name_english, 'unknown') AS product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM {{ ref('silver_products') }} p
LEFT JOIN {{ ref('silver_category_translation') }} t 
    ON p.product_category_name = t.category_key