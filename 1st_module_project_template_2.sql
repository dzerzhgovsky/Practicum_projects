/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Дзержговский Евгений Александрович
 * Дата: 09.04.2025
*/

-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Выделим категории по регионам и активности объявлений
catigories AS (
  	SELECT
  		*
  		, CASE  WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END AS region
  		, CASE  WHEN days_exposition >= 1 AND days_exposition <= 30 THEN 'до месяца'
  				WHEN days_exposition >= 31 AND days_exposition <= 90 THEN 'до трех месяцев'
  				WHEN days_exposition >= 91 AND days_exposition <= 180 THEN 'до полугода'
  				WHEN days_exposition > 180 THEN 'более полугода'
  				ELSE 'активные' END AS activity_ad
  		, last_price / total_area AS price_area
   	FROM real_estate.city AS c
   	LEFT JOIN real_estate.flats AS f USING (city_id)
   	LEFT JOIN real_estate.advertisement AS a USING (id)
   	LEFT JOIN real_estate.type AS t USING (type_id)
   	WHERE TYPE = 'город'
)
-- Выведем объявления без выбросов:
SELECT 
	region
	, activity_ad
	, ROUND(AVG(price_area)::numeric, 2) AS avg_price_area
	, ROUND(AVG(total_area)::numeric, 2) AS avg_area
	, COUNT(id) AS count_ad
	, ROUND(COUNT(id) / (SELECT COUNT(id) FROM real_estate.advertisement)::NUMERIC *100, 2) AS share_ad
	, ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms)::numeric, 2) AS mediana_rooms
  	, ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony)::numeric, 2) AS mediana_balcony
  	, ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor)::numeric, 2) AS mediana_floor
FROM catigories
WHERE id IN (SELECT * FROM filtered_id)
GROUP BY region, activity_ad
ORDER BY region, avg_price_area;


-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
activity_first AS (
	SELECT 
		EXTRACT(MONTH FROM first_day_exposition) AS month_first_day_exposition
		, COUNT(f.id) AS count_ad_first
		, ROUND(COUNT(id) / (SELECT COUNT(id) FROM real_estate.advertisement)::NUMERIC *100, 2) AS share_ad_first
		, RANK() OVER (ORDER BY COUNT(id) DESC) AS rank_first
		, ROUND(AVG(a.last_price / f.total_area)::numeric, 2) AS avg_price_area
		, ROUND(AVG(f.total_area)::numeric, 2) AS avg_total_area
	FROM real_estate.flats AS f
	LEFT JOIN real_estate.advertisement AS a USING (id)
	LEFT JOIN real_estate.city AS c USING (city_id)
	LEFT JOIN real_estate.TYPE AS t USING (type_id)
	WHERE id IN (SELECT * FROM filtered_id)
			AND days_exposition IS NOT NULL 
			AND (DATE_TRUNC('year', first_day_exposition) BETWEEN '2015-01-01' AND '2018-12-31')
			AND t.TYPE = 'город'
	GROUP BY month_first_day_exposition
	ORDER BY count_ad_first DESC
),
activity_last AS (
	SELECT 
		EXTRACT(MONTH FROM (first_day_exposition + days_exposition * INTERVAL '1 day')::date) AS month_last_day_exposition
		, COUNT(f.id) AS count_ad_last
		, ROUND(COUNT(id) / (SELECT COUNT(id) FROM real_estate.advertisement)::NUMERIC *100, 2) AS share_ad_last
		, RANK() OVER (ORDER BY COUNT(id) DESC) AS rank_last
		, ROUND(AVG(a.last_price / f.total_area)::numeric, 2) AS avg_price_area
		, ROUND(AVG(f.total_area)::numeric, 2) AS avg_total_area
	FROM real_estate.flats AS f
	LEFT JOIN real_estate.advertisement AS a USING (id)
	LEFT JOIN real_estate.city AS c USING (city_id)
	LEFT JOIN real_estate.TYPE AS t USING (type_id)
	WHERE id IN (SELECT * FROM filtered_id)
			AND days_exposition IS NOT NULL 
			AND (DATE_TRUNC('year', first_day_exposition) BETWEEN '2015-01-01' AND '2018-12-31')
			AND t.TYPE = 'город'
	GROUP BY month_last_day_exposition
	ORDER BY count_ad_last DESC
)
SELECT *
FROM activity_first AS af
LEFT JOIN activity_last AS al ON af.month_first_day_exposition = al.month_last_day_exposition;


-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
)
SELECT 
	city
	, COUNT(first_day_exposition) AS count_first
	, COUNT(days_exposition) AS count_end
	, ROUND(COUNT(days_exposition) / COUNT(id)::NUMERIC * 100, 2) AS share_end
	, ROUND(AVG(last_price / total_area)::numeric, 2) AS avg_price_area
	, ROUND(AVG(total_area)::numeric, 2) AS avg_area
	, ROUND(AVG(days_exposition)::numeric) AS avg_end
	, NTILE(15) OVER (ORDER BY COUNT(days_exposition) DESC)
FROM real_estate.city AS c
LEFT JOIN real_estate.flats AS f USING (city_id)
LEFT JOIN real_estate.advertisement AS a USING (id)
LEFT JOIN real_estate.type AS t USING (type_id)
WHERE id IN (SELECT * FROM filtered_id) AND city <> 'Санкт-Петербург'
GROUP BY city
ORDER BY count_end DESC
LIMIT 15;