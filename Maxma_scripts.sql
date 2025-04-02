--	*** BI Scripts ***

--	** Главный дэшборд **

--Бренд и менеджеры
--Таблица для сведения исторических данных по ответственным менеджерам по каждому бренду
create live view bi_brand_managers with refresh 14400 as
with t as
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) as dt
	, JSONExtractString(JSONExtractString(settings, 'accountManager'),'username') as accountManager --аккаунт-маркетолог, кто ведёт уже запущенный бренд
	, JSONExtractString(settings, 'salesManager') as salesManager --менеджер по продажам, кто ведёт первичные переговоры и доводит до продажи
	, JSONExtractString(settings, 'projectManager') as projectManager --проектный менеджер запускает проект (настраивает интеграции и т.п.)
from brand_settings_history --таблица с историческими данными по брендам
where globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')), --исключения по брендам, эти бренды тестовые
m as
(select
	  brand_id
	, dt as dt_from
	, any(dt) over (partition by brand_id order by dt rows between 1 following and 1 following) - 1 as dt_to
	, accountManager
	, salesManager
	, projectManager
from t),
--Тут делаем календарь дат от 2017 года до сегодня
toStartOfDay(date('2017-01-01', 'Europe/Moscow')) as dt_start,
toStartOfDay(date(date_trunc('day',now(), 'Europe/Moscow'))) as dt_end,
cal as
(select 
arrayJoin(arrayMap(x -> toDate(x, 'Europe/Moscow'), range(toUInt32(dt_start), toUInt32(dt_end), 24*3600))) as calday),
brand_list as
(select
	distinct globalKey as brand_id
from brand
where globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')),
b as
(select 
	bl.brand_id,
	c.calday as dt
from brand_list bl
cross join cal c), --делаем матричную таблицу с календарём в привязке к каждому бренду
t0 as
(select
	  b.brand_id
	, b.dt
	, m.managerUsername as accountManager
	, null as salesManager
	, null as projectManager
from b
left join account_managers_historical m --исторические данные по аккаунт-маркетологам до октября 2022 года (история не велась, собирали вручную)
	on m.globalKey = toString(b.brand_id)
where b.dt >= m.dateFrom and b.dt <= coalesce(case when m.dateTo='1970-01-01' then date('2022-09-30') else m.dateTo end,date('2022-09-30'))),
t as --до октября 2022 года обнуляем ответственных
(select
	  b.brand_id
	, b.dt
	, case when b.dt < '2022-10-01' then 'Не назначен' 
		else coalesce(case when m.accountManager='' then 'Не назначен' else m.accountManager end,'Не назначен') end as accountManager
	, case when b.dt < '2022-10-01' then 'Не назначен' 
		else coalesce(case when m.salesManager='' then 'Не назначен' else m.salesManager end,'Не назначен') end as salesManager
	, case when b.dt < '2022-10-01' then 'Не назначен' 
		else coalesce(case when m.projectManager='' then 'Не назначен' else m.projectManager end,'Не назначен') end as projectManager
from b
left join m
	on m.brand_id = b.brand_id
where b.dt >= m.dt_from and b.dt <= m.dt_to)
select
	  t.brand_id
	, t.dt
	, case when t0.accountManager is not null then t0.accountManager else t.accountManager end as accountManager
	, t.salesManager
	, t.projectManager
from t
left join t0 on t0.brand_id = t.brand_id and t0.dt = t.dt
order by 1,2;

select * from bi_brand_managers;

--Статусы брендов
drop table bi_brand_status;
create live view bi_brand_status with refresh 14400 as
with t_fix as
(select
	  globalKey
	, case when globalKey = '9a3699e7-71fc-4c42-baf8-d029d1831263' and status = 0 
		then createdAt - interval '1 year' else createdAt end as createdAt --Правим ошибку в данных
	, status
from brand_status_history
where globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')), --тестовые бренды
t as
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) as dt
	, any(date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')))
		over (partition by globalKey order by createdAt, status rows between 1 following and 1 following) as dt_to
	, status
from t_fix)
select
	  brand_id
	, dt as dt_from
	, case when dt_to = date('1970-01-01') then date('2099-12-31') else dt_to end as dt_to --дата до которой статус активен
	, status
from t
order by 1,2;

select * from bi_brand_status;

--Абонентская плата по дням и статусы брендов
drop table bi_daily_fee;
create live view bi_daily_fee with refresh 14400 as
with 
toStartOfDay(date('2017-01-01', 'Europe/Moscow')) as dt_start,
toStartOfDay(date(date_trunc('day',now(), 'Europe/Moscow'))) as dt_end,
cal as --генерация календаря
(select 
arrayJoin(arrayMap(x -> toDate(x, 'Europe/Moscow'), range(toUInt32(dt_start), toUInt32(dt_end), 24*3600))) as calday),
brand_list as
(select
	distinct globalKey as brand_id
from brand
where globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')), --тестовые бренды
all_data as
(select 
	bl.brand_id,
	c.calday as dt
from brand_list bl
cross join cal c),
fee_d as
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',billedAt), 'Europe/Moscow')) as dt
	, sum(billingAmount) as daily_fee
from default.expense
where true
	and operation=0
group by 1,2),
dep as
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) as dt
	, sum(amount) as deposit
from default.deposit
group by 1,2),
t as
(select
	  a.brand_id as brand_id
	, a.dt as dt
	, coalesce(round(f.daily_fee * 365 / 12,0),0) as fee --считаем месячную абоненсткую плану из дневной
	, coalesce(f.daily_fee,0) as daily_fee
	, coalesce(d.deposit,0) as deposit
	, bs.status as status
from all_data a
left join fee_d f
	on f.brand_id = a.brand_id and f.dt = a.dt
left join bi_brand_status bs
	on bs.brand_id = a.brand_id
left join dep d
	on d.brand_id = a.brand_id and d.dt = a.dt
where a.dt >= bs.dt_from and a.dt < bs.dt_to),
brand_start as
(select 
	  globalKey as brand_id
	, coalesce(toDate(JSONExtractString(settings, 'integrationStartedAt')),
		date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow'))) as dt_int_start
from brand)
select
	  t.brand_id as brand_id
	, coalesce(bbm.accountManager,'Не назначен') as accountManager
	, coalesce(bbm.salesManager,'Не назначен') as salesManager
	, coalesce(bbm.projectManager,'Не назначен') as projectManager
	, t.dt as dt
	, t.fee as fee
	, t.daily_fee as daily_fee
	, t.deposit as deposit
	, coalesce(sum(t.deposit) over (partition by t.brand_id order by t.dt rows between unbounded preceding and current row),0)
	  - coalesce(sum(t.daily_fee) over (partition by t.brand_id order by t.dt rows between unbounded preceding and current row),0) as balance --считаем баланс клиента через разницу депозитов и списаний
	, t.status as status
from t
left join bi_brand_managers bbm on bbm.brand_id = t.brand_id and bbm.dt = t.dt
left join brand_start bs on bs.brand_id = t.brand_id
where t.dt >= bs.dt_int_start;

select * from bi_daily_fee;

--Дневная выручка
create live view bi_daily_revenue with refresh 14400 as
select
	  bdf.brand_id
	, bdf.accountManager
	, bdf.status
	, bdf.dt
	, sum(bdf.daily_fee) as revenue
from bi_daily_fee bdf
group by 1,2,3,4;

select * from bi_daily_revenue;

--Запуски брендов
drop table bi_daily_starts;
create live view bi_daily_starts with refresh 14400 as
with 
t0000 as
(select
	  brand_id
	, accountManager
	, dt
	, status
	, fee
	, case when any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) >= 3
		and any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) <> 5
		and any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) <> 6
		and (status < 2 or status >= 5) then 1 else 0 end as archive_flag --флаг перевода в архивный статус
from bi_daily_fee),
t000 as
(select
	  brand_id
	, accountManager
	, dt
	, status
	, fee
	, sum(archive_flag) over (partition by brand_id order by dt rows between unbounded preceding and 1 preceding) as af --считаем на дату в архиве ли бренд
from t0000),
t00 as
(select
	  brand_id
	, accountManager
	, dt
	, af
	, status
	, any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) as status_before
	, case when (fee>0 and (status='1' or status='2') and 
		sum(case when (status = '1' or status='2') then fee else 0 end) 
		over (partition by brand_id, af order by dt rows between unbounded preceding and 1 preceding)=0)
	  then fee else null end as fee_start --если есть переключение статусов или списание абонки, то считаем бренд запущенным
	, case when (fee>0 and (status='1' or status='2') and 
		sum(case when (status = '1' or status='2') then fee else 0 end) 
		over (partition by brand_id, af order by dt rows between unbounded preceding and 1 preceding)=0)
	  then dt else null end as fee_start_date
from t000),
t0 as
(select
	  brand_id
	, accountManager
	, dt
	, af
	, status
	, status_before
	, fee_start
	, fee_start_date
from t00),
t as
(select
	  brand_id
	, accountManager
	, dt
	, af
	, status
	, coalesce(fee_start,0) as fee_start
	, coalesce(max(t0.fee_start_date) over (partition by brand_id, af), date('2099-12-31')) as fee_start_date
from t0)
select
	  t.brand_id as brand_id
	, t.accountManager as accountManager
	, t.dt as dt
	, t.status as status
	, t.fee_start as fee_start
	, t.fee_start_date as fee_start_date
from t;

select * from bi_daily_starts;

--Динамика абонентки по дням (для ведения клиентов)
drop table bi_daily_fee_dynamic;
create live view bi_daily_fee_dynamic with refresh 14400 as
with t as
(select
	  df.brand_id
	, df.accountManager
	, df.dt
	, df.status
    , df.fee
	, df.fee - 
	  coalesce(any(df.fee) over (partition by df.brand_id order by df.dt rows between 1 preceding and 1 preceding),0) 
	  as fee_d
	, case when ds.brand_id is not null then 1 else 0 end as brand_start_flag --флаг запуска бренда
from bi_daily_fee df
left join 
	(select distinct brand_id, fee_start_date from bi_daily_starts)	ds
	on  ds.brand_id = df.brand_id
	and ds.fee_start_date = df.dt),
total as
(select
	  t.brand_id as brand_id
	, t.accountManager as accountManager
	, t.dt as dt
    , sum(t.fee) as fee
	, sum(t.fee_d) as fee_delta_all
	, sum(case when t.status <> 0 and t.status <> 5 and t.status <> 6 and t.brand_start_flag = 0 then t.fee_d else 0 end) as fee_delta --разница абонки на сегодня в сравнении с вчерашней
	, sum(case when t.status <> 0 and t.status <> 5 and t.status <> 6 and t.fee_d > 0 and t.brand_start_flag = 0 then t.fee_d else 0 end) as fee_up
	, sum(case when t.status <> 0 and t.status <> 5 and t.status <> 6 and t.fee_d < 0 and t.brand_start_flag = 0 then t.fee_d else 0 end) as fee_down
from t
group by 1,2,3)
select
	  brand_id
	, accountManager
	, dt
    , fee
	, fee_delta_all
	, fee_delta
	, fee_up
	, fee_down
	, case when sum(fee_up + fee_down) over (partition by brand_id, date_trunc('month',dt)) > 0 then
		case when dt = first_value(dt) over (partition by brand_id, date_trunc('month',dt) order by fee_up desc) then
			sum(fee_up + fee_down) over (partition by brand_id, date_trunc('month',dt))
		else 0 end
	  else 0 end as fee_up_rollup --считаем сумму роста абонки за календарный месяц
	 , case when sum(fee_up + fee_down) over (partition by brand_id, date_trunc('month',dt)) < 0 then
	  	case when dt = first_value(dt) over (partition by brand_id, date_trunc('month',dt) order by fee_down) then
			sum(fee_up + fee_down) over (partition by brand_id, date_trunc('month',dt))
		else 0 end
	  else 0 end as fee_down_rollup --считаем сумму падения абонки за календарный месяц 
from total
order by 1,3;

select * from bi_daily_fee_dynamic;

--LTV
drop table bi_daily_ltv;
create live view bi_daily_ltv with refresh 14400 as
with ind as
(select
	  distinct
	  globalKey as brand_id
	, first_value(replaceAll(ind,'"','')) over (partition by globalKey) as industry --Индустрия бренда (рынок, где бренд работает)
from brand
	array join JSONExtractArrayRaw(coalesce(JSONExtractString(extraFields, 'industry'), '[]')) as ind),
t0 as
(select
	  t.brand_id as brand_id
	, t.accountManager as accountManager
	, t.salesManager as salesManager
	, t.dt as dt
	, t.status as status
	, t.daily_fee as daily_fee
	, case 
		when ((any(t.status) over (partition by t.brand_id order by t.dt rows between 1 preceding and 1 preceding)) <= 1
		or (any(t.status) over (partition by t.brand_id order by t.dt rows between 1 preceding and 1 preceding)) >= 5)
		and t.status in ('2','3')
	  then t.dt else null end as old_status_date --флаг переключения на статус приостановлено или архивный
	, sum(t.daily_fee) over (partition by t.brand_id order by dt rows between unbounded preceding and current row) as LTV_on_date
	, sum(case when t.daily_fee>0 then 1 else 0 end) over (partition by t.brand_id order by dt rows between unbounded preceding and current row) as LT_on_date
from bi_daily_fee t
--left join bi_brand_managers bbm on bbm.brand_id = t.brand_id and bbm.dt = t.dt
),
t as
(select
	  t0.brand_id as brand_id
	, coalesce(i.industry, 'Без индустрии') as industry
	, t0.accountManager as accountManager
	, t0.salesManager as salesManager
	, t0.dt as dt
	, t0.status as status
	, t0.daily_fee as daily_fee
	, t0.dt - coalesce(max(t0.old_status_date) over (partition by t0.brand_id order by t0.dt rows between unbounded preceding and current row),t0.dt) as old_status_days --как давно бренд был переведён в статусы приостановлен или архивный (нужно для расчёта LTV)
	, t0.LTV_on_date as LTV_on_date
	, t0.LTV_on_date as LTV_on_date
	, t0.LT_on_date as LT_on_date
from t0
left join ind i on i.brand_id = t0.brand_id),
lt_old_0 as
(select
	  dt
	, industry
	, avg(case when status in ('2','3') and old_status_days <= 365 then LT_on_date else null end) as LT_old_365 --среднее LT по брендам, которые ушли в архив не позже 365 дней)
	, avg(case when status in ('2','3') and old_status_days <= 545 then LT_on_date else null end) as LT_old_545 -- далее по аналогии с 365 днями
	, avg(case when status in ('2','3') and old_status_days <= 730 then LT_on_date else null end) as LT_old_730
	, avg(case when status in ('2','3') and old_status_days <= 1095 then LT_on_date else null end) as LT_old_1095
	, avg(case when status in ('2','3') and old_status_days <= 1460 then LT_on_date else null end) as LT_old_1460
	, avg(case when status in ('2','3') then LT_on_date else null end) as LT_old_overall
from t
where LTV_on_date > 0
group by 1,2),
lt_old as
(select
	  dt
	, industry
	, coalesce(LT_old_365, LT_old_545, LT_old_730, LT_old_1095, LT_old_1460, LT_old_overall,0) as LT_old --для брендов в зависимости от того как давно он ушёл в архив выводим LT (чтобы для всех случаев посчитать LT, если, например, не будет брендов, которые ушли в архив менее 365 дней)
	, case
		when LT_old_365 is not null then 365
		when LT_old_545 is not null then 545
		when LT_old_730 is not null then 730
		when LT_old_1095 is not null then 1095
		when LT_old_1460 is not null then 1460
		else 9999
	  end as osd_norm --число дней, сколько бренд в архиве
from lt_old_0),
lt_old_0_account as --тут аналогично для lt_old, только считаем в разрезе аккаунт-маркетологов (это нужно, чтобы посчитать LTV справедливо для менеджера)
(select
	  dt
	, accountManager
	, avg(case when status in ('2','3') and old_status_days <= 365 then LT_on_date else null end) as LT_old_365
	, avg(case when status in ('2','3') and old_status_days <= 545 then LT_on_date else null end) as LT_old_545
	, avg(case when status in ('2','3') and old_status_days <= 730 then LT_on_date else null end) as LT_old_730
	, avg(case when status in ('2','3') and old_status_days <= 1095 then LT_on_date else null end) as LT_old_1095
	, avg(case when status in ('2','3') and old_status_days <= 1460 then LT_on_date else null end) as LT_old_1460
	, avg(case when status in ('2','3') then LT_on_date else null end) as LT_old_overall
from t
where LTV_on_date > 0
group by 1,2),
lt_old_account as
(select
	  dt
	, accountManager
	, coalesce(LT_old_365, LT_old_545, LT_old_730, LT_old_1095, LT_old_1460, LT_old_overall,0) as LT_old
	, case
		when LT_old_365 is not null then 365
		when LT_old_545 is not null then 545
		when LT_old_730 is not null then 730
		when LT_old_1095 is not null then 1095
		when LT_old_1460 is not null then 1460
		else 9999
	  end as osd_norm
from lt_old_0_account),
lt_old_0_sales as --тут аналогично для lt_old, только считаем в разрезе менеджеров продаж (это нужно, чтобы посчитать LTV справедливо для менеджера)
(select
	  dt
	, salesManager
	, avg(case when status in ('2','3') and old_status_days <= 365 then LT_on_date else null end) as LT_old_365
	, avg(case when status in ('2','3') and old_status_days <= 545 then LT_on_date else null end) as LT_old_545
	, avg(case when status in ('2','3') and old_status_days <= 730 then LT_on_date else null end) as LT_old_730
	, avg(case when status in ('2','3') and old_status_days <= 1095 then LT_on_date else null end) as LT_old_1095
	, avg(case when status in ('2','3') and old_status_days <= 1460 then LT_on_date else null end) as LT_old_1460
	, avg(case when status in ('2','3') then LT_on_date else null end) as LT_old_overall
from t
where LTV_on_date > 0
group by 1,2),
lt_old_sales as
(select
	  dt
	, salesManager
	, coalesce(LT_old_365, LT_old_545, LT_old_730, LT_old_1095, LT_old_1460, LT_old_overall,0) as LT_old
	, case
		when LT_old_365 is not null then 365
		when LT_old_545 is not null then 545
		when LT_old_730 is not null then 730
		when LT_old_1095 is not null then 1095
		when LT_old_1460 is not null then 1460
		else 9999
	  end as osd_norm
from lt_old_0_sales),
lt_base as
--LT считаем как среднее по брендам, которые ушли в архив меньше числа дней рассчитаного для каждого дня выше + если они "живут" больше этого числа дней
(select
	  t.brand_id as brand_id 
	, t.industry as industry
	, t.accountManager as accountManager
	, t.salesManager as salesManager
	, t.dt as dt
	, t.LT_on_date as LT
	, case when 
		(t.status in ('2','3') and t.old_status_days <= lto.osd_norm) or
		(t.status in ('1') and t.LT_on_date >= lto.LT_old)
	  then 1 else 0 end as LT_flag
	, case when 
		(t.status in ('2','3') and t.old_status_days <= ltoa.osd_norm) or
		(t.status in ('1') and t.LT_on_date >= ltoa.LT_old)
	  then 1 else 0 end as LT_flag_account --LT для логики в разрезе аккаунт-маркетологов
	, case when 
		(t.status in ('2','3') and t.old_status_days <= ltos.osd_norm) or
		(t.status in ('1') and t.LT_on_date >= ltos.LT_old)
	  then 1 else 0 end as LT_flag_sales --LT для логики в разрезе менеджеров по продажам
from t
left join lt_old lto on lto.dt = t.dt and lto.industry = t.industry
left join lt_old_account ltoa on ltoa.dt = t.dt and ltoa.accountManager = t.accountManager
left join lt_old_sales ltos on ltos.dt = t.dt and ltos.salesManager = t.salesManager),
lt as  --считаем среднее LT на день по индустрии (это стандартный метод, так как для каждой индустрии бренды работают специфически)
(select
	  dt
	, industry
	, avg(case when LT_flag = 1 then LT else null end) as LT
from lt_base
group by 1,2),
lt_account as --считаем среднее LT для разреза аккаунт-маркетологов
(select
	  dt
	, accountManager
	, avg(case when LT_flag_account = 1 then LT else null end) as LT
from lt_base
group by 1,2),
lt_sales as --считаем среднее LT для разреза МП (менеджеров продаж)
(select
	  dt
	, salesManager
	, avg(case when LT_flag_sales = 1 then LT else null end) as LT
from lt_base
group by 1,2)
select
	  t.brand_id as brand_id
	, t.accountManager as accountManager
	, t.salesManager as salesManager
	, t.dt as dt
	, t.status as status
	, t.LTV_on_date as LTV_on_date
	, t.LT_on_date as LT_on_date
	, lt.LT as LT
	, case when t.status in ('1') then t.daily_fee * lt.LT else null end as LTV --LTV мы считаем как дневное списание по бренду умноженной на нормативный срок LT, который мы рассчитали выше (то есть не важно сколько прожил бренд, мы прогнозируем сколько он нам принёсет за его прогнозный срок жизни, который мы считаем статистически) 
	, lta.LT as LT_account_manager
	, lts.LT as LT_sales_manager
from t
left join lt lt on lt.dt = t.dt and lt.industry = t.industry
left join lt_account lta on lta.dt = t.dt and lta.accountManager = t.accountManager
left join lt_sales lts on lts.dt = t.dt and lts.salesManager = t.salesManager;

select * from bi_daily_ltv;

--AOV по дням
create live view bi_daily_aov with refresh 14400 as
select
	  df.brand_id as brand_id
	, df.accountManager as accountManager
	, df.dt as dt
	, df.fee as AOV
from bi_daily_fee df
left join 
	(select distinct brand_id, fee_start_date from bi_daily_starts)	ds
	on  ds.brand_id = df.brand_id
	and ds.fee_start_date = df.dt
where true
	and df.fee>0
	and df.status in ('1')
	and ds.brand_id is null;

select * from bi_daily_aov;

--V запуска (срок запуска бренда в днях от момента заведения в систему до запуска)
drop table bi_daily_v_start;
create live view bi_daily_v_start with refresh 14400 as
with t00 as
(select
	  brand_id
	, accountManager
	, dt
	, status
	, fee
	, case when ((any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding)) < 3
		or (any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding)) >= 5)
		and status >= 3 and status <> 5 and status <> 6 then 1 else 0 end as archive_flag
from bi_daily_fee),
t0 as
(select
	  brand_id
	, accountManager
	, dt
	, status
	, fee
	, sum(archive_flag) over (partition by brand_id order by dt rows between unbounded preceding and 1 preceding) as af
from t00),
tt as
(select
	  brand_id
	, accountManager
	, af
	, dt
	, status
	, any(status) over (partition by brand_id, af order by dt rows between 1 preceding and 1 preceding) as pre_status
from t0),
t as
(select
	  brand_id
	, accountManager
	, af
	, dt
	, status
	, sum(case when (status = 0 or status = 5) and not ((month(dt) = 12 and day(dt) = 31) or (month(dt) = 1 and day(dt) <= 8)) then 1 else 0 end)
		over (partition by brand_id, af order by dt rows between unbounded preceding and current row) as status_0_days
	, case when status = 1 
			and (pre_status = 0	or pre_status = 5 or pre_status = 6)
			and sum(case when status = 0 or status = 5 or status = 6 then 1 else 0 end)
			over (partition by brand_id, af order by dt rows between 1 following and unbounded following) = 0
	  then dt else null end as last_start_dt
from tt)
select
	  t.brand_id
	, t.af
	, t.accountManager as accountManager
	, t.last_start_dt as dt
	, t.status_0_days as v_start_days
from t
where last_start_dt is not null; --считаем только для запущенных брендов

select * from bi_daily_v_start;

--SLA запуска
drop table bi_daily_sla_v_start;
create live view bi_daily_sla_v_start with refresh 14400 as
select
	  s.brand_id as brand_id
	, b.name as brand_name
	, s.accountManager as accountManager
	, s.dt as dt
	, s.status as status
	, case
		when s.status = '0' then 'На интеграции'
		when s.status = '5' then 'Подготовка к запуску'
		when s.status = '1' then 'Активен'
		when s.status = '2' then 'Приостановлен'
		when s.status = '3' then 'Архивный'
		when s.status = '4' then 'Удалён'
		when s.status = '6' then 'Возврат в продажи'
	  else 'Не известный' end as status_name
	, s.fee_start as fee_start
	, s.fee_start_date as fee_start_date
	, case when s.dt = s.fee_start_date then 1 else 0 end as start_flag
	, case when s.dt <= s.fee_start_date then
		sum(case when s.status in (0,5) then 1 else 0 end) over (partition by s.brand_id order by s.dt) end as v_start_days
from bi_daily_starts s
left join brand b on b.globalKey = s.brand_id;

select * from bi_daily_sla_v_start;

--Данные по клиентам брендов и абонентки в зависимости от их количества (раньше, когда не было тарифов списание проходило по этой логике)
drop table bi_daily_brand_clients;
create live view bi_daily_brand_clients with refresh 14400 as
with b as --бренды с датой первого появления в системе
(select
	  brand_id
	, dt
	, min(dt) over (partition by brand_id) as min_dt
from bi_daily_fee),
c0 as --число клиентов созданные на определённую дату
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) as dt
	, toInt64(count(distinct id)) as clients
from client
group by 1,2
union all --число удалённых клиентов на дату (дата удаления для нас дата обновления записи)
select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',updatedAt), 'Europe/Moscow')) as dt
	, toInt64(-count(distinct id)) as clients
from client
where isDeleted = true
group by 1,2),
c as --сумма созданных или удалённых клиентов бренда на дату
(select
	  brand_id
	, dt
	, sum(clients) as clients
from c0
group by 1,2),
c1 as
(select 
	  coalesce(b.brand_id, c.brand_id) as brand_id
	, coalesce(b.dt, c.dt) as dt
	, max(b.min_dt) over (partition by coalesce(b.brand_id, c.brand_id)) as min_dt
	, coalesce(c.clients,0) as clients
from b
full join c
	on c.brand_id = b.brand_id and c.dt = b.dt),
c_all0 as --считаем на дату сколько накопительно клиентов есть у бренда
(select
	  brand_id
	, dt
	, min_dt
	, sum(clients) over (partition by brand_id order by dt rows between unbounded preceding and current row) as clients
from c1),
c_all as
(select
	  brand_id
	, dt
	, clients
from c_all0
where dt >= min_dt),
price_h00 as --прайс по бренду сколько должно быть списано в зависимости от клиентской базы
(select
      bph.globalKey as brand_id
    , date(date_trunc('day',date_trunc('hour',bph.createdAt), 'Europe/Moscow')) + 1 as dt
    , toInt64(JSONExtractString(prc_unnest, 'clients')) as clients
    , JSONExtractFloat(prc_unnest, 'monthly') as fee_value
from default.brand_price_history bph
    array join JSONExtractArrayRaw(coalesce(bph.price_perClient, '[]')) as prc_unnest),
price_h0 as
(select
	  brand_id
	, dt as dt_from
	, any(dt) over (partition by brand_id, clients order by dt rows between 1 following and 1 following) - 1 as dt_to
	, clients
	, fee_value
from price_h00),
price_h0c as
(select
	  brand_id
	, dt_from
	, case when dt_from < max(dt_from) over (partition by brand_id) and dt_to = '2149-06-06'
		then max(dt_from) over (partition by brand_id) - 1 else dt_to end as dt_to
	, clients
	, fee_value
from price_h0),
price_h as
(select
	  brand_id
	, dt_from
	, dt_to
	, case 
		when any(clients) over (partition by brand_id, dt_from order by clients rows between 1 preceding and 1 preceding) = 0 then 0 else
		any(clients) over (partition by brand_id, dt_from order by clients rows between 1 preceding and 1 preceding) + 1 end as clients_mn
	, clients as clients_mx
	, any(clients) over (partition by brand_id, dt_from order by clients rows between 1 following and 1 following) as clients_next
	, fee_value
from price_h0c
where dt_from <= dt_to),
price_h_f as --финальная таблица с ценами по диапазону клиентской базы для каждого бренда
(select
	  brand_id
	, dt_from
	, dt_to
	, clients_mn as clients_min
	, clients_mx as clients_max
	, fee_value
from price_h
union all
select
	  brand_id
	, dt_from
	, dt_to
	, clients_mx + 1 as clients_min
	, 999999999 as clients_max
	, fee_value
from price_h
where clients_next = 0),
f as --объединяем сколько клиентов у клиента на дату и какая абонка должна быть - получаем прогноз абонки по бренду
(select
	  c.brand_id as brand_id
	, c.dt as dt
	, c.clients as clients
	, p.clients_min as clients_min
	, p.clients_max as clients_max
	, p.fee_value as fee_value
	, toInt64(JSONExtractString(b.extraFields, 'expectedClientsCount')) as clients_forecast --прогноз клиентской базы, заполняется в процессе интеграции бренда до запуска и в первые дни после запуска
from c_all c
left join brand b on b.globalKey = c.brand_id
left join price_h_f p
	on p.brand_id = c.brand_id and p.dt_from <= p.dt_to
where c.dt >= coalesce(p.dt_from, date('1970-01-01')) and c.dt <= coalesce(p.dt_to, date('2149-06-06')) 
and c.clients >= coalesce(p.clients_min,0) and c.clients <= coalesce(p.clients_max,999999999))
select
	  f.brand_id as brand_id
	, f.dt as dt
	, f.clients as clients
	, f.clients_min as clients_min
	, f.clients_max as clients_max
	, f.fee_value as fee_value
	, f.clients_forecast as clients_forecast
	, p.fee_value as fee_value_forecast
from f
left join price_h_f p
	on p.brand_id = f.brand_id and p.dt_from <= p.dt_to and f.clients_forecast is not null
where f.dt >= coalesce(p.dt_from, date('1970-01-01')) and f.dt <= coalesce(p.dt_to, date('2149-06-06')) 
and coalesce(f.clients_forecast,0) >= coalesce(p.clients_min,0) and coalesce(f.clients_forecast,0) <= coalesce(p.clients_max,999999999);

select * from bi_daily_brand_clients bdbc where fee_value is null;

--Даты пилота (пилотом считаем первые 30 дней после старта бренда)
drop table bi_brand_pilot_dates;
create live view bi_brand_pilot_dates with refresh 14400 as
select
	  brand_id
	, min(fee_start_date) as pilotFrom
	, min(fee_start_date + 29) as pilotTo
from bi_daily_starts
group by 1;

select * from bi_brand_pilot_dates;


--Бренды по статусам
drop table bi_daily_clients;
create live view bi_daily_clients with refresh 14400 as
with t as
(select
	  brand_id
	, accountManager
	, dt
	, status
	, case when status > 2 and status <> 5 and status <> 6 and
		(any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) < 3) and
		(any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) > 0)
	  then 1 else 0 end as lost_flag
from bi_daily_fee),
total as
(select
	  t.brand_id as brand_id
	, t.accountManager as accountManager
	, t.dt as dt
	, case when t.status = 0 then 1 else 0 end as integration
	, case when t.status = 5 then 1 else 0 end as integration_active
	, case when t.status = 1 and t.dt >= b.pilotFrom and t.dt <= b.pilotTo then 1 else 0 end as pilot
	, case when t.status = 2 then 1 else 0 end as stopped
	--, case when t.lost_flag = 1 then 1 else 0 end as lost
	, case when t.status > 2 and t.status <> 5 and t.status <> 6 then 1 else 0 end as lost
	, case when t.status = 1 then 1 else 0 end as total
from t 
left join bi_brand_pilot_dates b on b.brand_id = t.brand_id)
select
	  brand_id
	, accountManager
	, dt
	, integration
	, integration_active
	, pilot
	, stopped
	, lost
	, total
	, case when integration = 1 and any(integration) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) = 0
		then 1 else 0 end as integration_flag
	, case when integration_active = 1 and any(integration_active) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) = 0
		then 1 else 0 end as integration_active_flag
	, case when pilot = 1 and any(pilot) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) = 0
		then 1 else 0 end as pilot_flag
	, case when stopped = 1 and any(stopped) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) = 0
		then 1 else 0 end as stopped_flag
	, case when lost = 1 and any(lost) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) = 0
		then 1 else 0 end as lost_flag
from total;

select * from bi_daily_clients;

--Потери и прирост по дням по типам изменения абонки (то есть может быть прирост от запуска или от роста клиентской базы и т.п.)
--Сейчас часть событий лежит внутри тарифа, а раньше считали через подключение/отключения модулей
--Тут не буду описывать детально логику, лучше если будет необходимость погрузиться
drop table bi_daily_fee_type_dynamic;
create live view bi_daily_fee_type_dynamic with refresh 14400 as
with fee_type00 as
(select
      bph.globalKey as brand_id
    , bph.createdAt
    , case when JSONExtractString(opt_unnest, 'name') like '%'
    	then 'hand_module' else 'hand_module' end as fee_type --смотрим изменения абонки от модулей (по идее сейчас все делаем через тариф)
    , sum(JSONExtractFloat(opt_unnest, 'monthly')) as fee_value 
from default.brand_price_history bph
    array join JSONExtractArrayRaw(coalesce(bph.price_options, '[]')) as opt_unnest
group by 1,2,3),
fee_type0 as
(select
	  brand_id
	, createdAt
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) + 1 as dt
	, fee_type
	, fee_value - 
	  coalesce(any(fee_value) 
		over (partition by brand_id, fee_type order by createdAt rows between 1 preceding and 1 preceding),0) as fee_delta
from fee_type00),
fee_type as
(select
	  brand_id
	, dt
	, toInt64(sum(case when fee_type = 'hand_module' then fee_delta else 0 end)) as modul_fee_delta
from fee_type0
group by 1,2),
fee_dyn as
(select
	  brand_id
	, accountManager
	, salesManager
	, projectManager
	, dt
	, status
	, any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) as status_pre
	, any(status) over (partition by brand_id order by dt rows between 2 preceding and 2 preceding) as status_pre_pre
	, fee
	, fee - 
	  coalesce(any(fee) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding),0) 
	  as fee_delta
from bi_daily_fee),
fee_corr as --тут берём фактическое изменение абонки, так как иногда данные по модулям не совпадают с реальностью
(select
	  brand_id
	, dt
	, toInt64(fee_value - coalesce(
		any(fee_value) over (partition by brand_id, clients order by dt rows between 1 preceding and 1 preceding),fee_value)) as corr_fee_delta
from bi_daily_brand_clients),
pilot_end as
(select
	  brand_id
	, dt
	, case when pilot = 0 and coalesce(any(pilot) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding),0) = 1 then
		1 else 0 end pilot_stop_flag
from bi_daily_clients),
fee_tariff_0 as --тут смотрим изменения в тарифах
(select 
	  bdt.brand_id as brand_id
	, bdt.dt as dt
	, sum(bdt.tariff_fee) as tariff_fee
from bi_daily_tariff_module bdt
join (select distinct brand_id, dt from bi_daily_fee where fee > 0) bdf on bdf.brand_id = bdt.brand_id and bdf.dt = bdt.dt
group by 1,2),
fee_tariff as 
(select
	  brand_id
	, dt
	, toInt64(round(tariff_fee - 
	  coalesce(any(tariff_fee) 
		over (partition by brand_id order by dt rows between 1 preceding and 1 preceding),0))) as tariff_fee_delta
from fee_tariff_0),
all_t as
(select
	  fd.brand_id as brand_id
	, fd.accountManager as accountManager
	, fd.salesManager as salesManager
	, fd.projectManager as projectManager
	, fd.dt as dt
	, fd.status as status
	, fd.status_pre as status_pre
	, coalesce(pe.pilot_stop_flag,0) as pilot_stop_flag
	, fd.fee as fee
	, case when (fd.status= '1' or (fd.status = '2' and fd.status_pre = '1')) then fd.fee_delta else 0 end as fee_active_delta
	, case when (fd.fee_delta>0 and coalesce(ft.modul_fee_delta,0) + coalesce(fc.corr_fee_delta,0) < fd.fee_delta)
			or  (fd.fee_delta<0 and coalesce(ft.modul_fee_delta,0) + coalesce(fc.corr_fee_delta,0) > fd.fee_delta)
		then coalesce(ft.modul_fee_delta,0) 
		else toInt64(fd.fee_delta * coalesce(coalesce(ft.modul_fee_delta,0) / nullif(coalesce(ft.modul_fee_delta,0) + coalesce(fc.corr_fee_delta,0),0),0)) 
		end as modul_fee_delta
	, case when (fd.fee_delta>0 and coalesce(ft.modul_fee_delta,0) + coalesce(fc.corr_fee_delta,0) < fd.fee_delta)
			or  (fd.fee_delta<0 and coalesce(ft.modul_fee_delta,0) + coalesce(fc.corr_fee_delta,0) > fd.fee_delta)
		then coalesce(fc.corr_fee_delta,0) 
		else toInt64(fd.fee_delta * coalesce(coalesce(fc.corr_fee_delta,0) / nullif(coalesce(ft.modul_fee_delta,0) + coalesce(fc.corr_fee_delta,0),0),0)) 
		end as corr_fee_delta
	, coalesce(ds.fee_start,0) as fee_start
	, case when fd.status_pre in ('1') and (fd.status = '0' or fd.status = '5' or fd.status = '6') and fee_delta<0 then fee_delta else 0 end fee_to_integration
	, case when fd.status_pre in ('0','5','6') and fd.status = '1' and coalesce(ds.fee_start,0)=0 and fee_delta>0 then fee_delta else 0 end fee_back_from_integration
	, case when fd.status_pre in ('1','2') and fd.status > 2 and fd.status <> 5 and fd.status <> 6 and fee_delta<0 then fd.fee_delta else 0 end as fee_end
	, case when fd.status_pre > 2 and fd.status_pre <> 5 and fd.status_pre <> 6 and fd.status in ('1','2') and fee_delta>0 then fd.fee_delta else 0 end as fee_back_from_end
	, case when (fd.status_pre in ('1') or fd.status_pre_pre in ('1')) and fd.status = '2' and fee_delta<0 then fee_delta else 0 end fee_stop
	, case when (fd.status_pre in ('2') or fd.status_pre_pre in ('2')) and fd.status = '1' and fee_delta>0 then fee_delta else 0 end fee_back_from_stop
from fee_dyn fd
left join fee_type ft
	on  ft.brand_id = fd.brand_id
	and ft.dt = fd.dt
left join bi_daily_starts ds
	on  ds.brand_id = fd.brand_id
	and ds.dt = fd.dt
left join fee_corr fc
	on  ds.brand_id = fc.brand_id
	and ds.dt = fc.dt
left join pilot_end pe
	on  ds.brand_id = pe.brand_id
	and ds.dt = pe.dt),
all_t_f as
(select
	  a.brand_id as brand_id
	, a.accountManager as accountManager
	, a.salesManager as salesManager
	, a.projectManager as projectManager
	, a.dt as dt
	, a.status as status
	, a.status_pre as status_pre
	, a.fee as fee
	, a.fee_start as fee_start
	, a.modul_fee_delta as modul_fee_delta
	, a.corr_fee_delta as corr_fee_delta
	, a.fee_to_integration as fee_to_integration
	, a.fee_back_from_integration as fee_back_from_integration
	, a.fee_stop as fee_stop
	, a.fee_back_from_stop as fee_back_from_stop
	, a.fee_end as fee_end
	, a.fee_back_from_end as fee_back_from_end
	, case when a.pilot_stop_flag = 1 then
		a.fee_active_delta - a.fee_start - a.modul_fee_delta - a.corr_fee_delta - a.fee_back_from_integration - a.fee_back_from_stop - a.fee_back_from_end
	  else 0 end as fee_pilot_stop
	, case when pilot_stop_flag = 0 and a.fee > 0 and coalesce(ft.tariff_fee_delta,0) <> 0 then
		case when ft.tariff_fee_delta <= a.fee_active_delta - a.fee_start - a.modul_fee_delta - a.corr_fee_delta - a.fee_back_from_integration - a.fee_back_from_stop - a.fee_back_from_end
			then ft.tariff_fee_delta 
			else a.fee_active_delta - a.fee_start - a.modul_fee_delta - a.corr_fee_delta - a.fee_back_from_integration - a.fee_back_from_stop - a.fee_back_from_end
		end
	  else 0 end as fee_tariff_delta
	, case when pilot_stop_flag = 0 then 
		a.fee_active_delta - a.fee_start - a.modul_fee_delta - a.corr_fee_delta - a.fee_back_from_integration - a.fee_back_from_stop - a.fee_back_from_end -
		case when pilot_stop_flag = 0 and a.fee > 0 and coalesce(ft.tariff_fee_delta,0) <> 0 then
			case when ft.tariff_fee_delta <= a.fee_active_delta - a.fee_start - a.modul_fee_delta - a.corr_fee_delta - a.fee_back_from_integration - a.fee_back_from_stop - a.fee_back_from_end
				then ft.tariff_fee_delta 
				else a.fee_active_delta - a.fee_start - a.modul_fee_delta - a.corr_fee_delta - a.fee_back_from_integration - a.fee_back_from_stop - a.fee_back_from_end
			end
	  	else 0 end
	  else 0 end as fee_clients_base
from all_t a
left join fee_tariff ft on ft.brand_id = a.brand_id and ft.dt = a.dt),
all_data0 as
(select
	  brand_id
	, accountManager
	, salesManager
	, projectManager
	, dt
	, delta_type0
	, fee_delta
from all_t_f
array join
	splitByString(', ', 'fee_start, modul_fee_delta, corr_fee_delta, fee_to_integration, fee_back_from_integration, fee_stop, fee_back_from_stop, fee_end, fee_back_from_end, fee_pilot_stop, fee_tariff_delta, fee_clients_base') as delta_type0,
	[fee_start, modul_fee_delta, corr_fee_delta, fee_to_integration, fee_back_from_integration, fee_stop, fee_back_from_stop, fee_end, fee_back_from_end, fee_pilot_stop, fee_tariff_delta, fee_clients_base] as fee_delta),
all_data as
(select
	  t.brand_id as brand_id
	, t.accountManager as accountManager
	, t.salesManager as salesManager
	, t.projectManager as projectManager
	, t.dt as dt
	, case 
		when t.delta_type0 = 'fee_start' then 'Запуск'
		when t.delta_type0 = 'modul_fee_delta' and t.fee_delta >=0 then 'Включение модулей'
		when t.delta_type0 = 'modul_fee_delta' and t.fee_delta <0 then 'Отключение модулей'
		when t.delta_type0 = 'corr_fee_delta' and t.fee_delta >=0 then 'Ручные корректировки вверх'
		when t.delta_type0 = 'corr_fee_delta' and t.fee_delta <0 then 'Ручные корректировки вниз'
		when t.delta_type0 = 'fee_to_integration' and t.fee_delta <0 then 'Возврат на интеграцию'
		when t.delta_type0 = 'fee_back_from_integration' and t.fee_delta >=0 then 'Возвращение с интеграции'
		when t.delta_type0 = 'fee_stop' and t.fee_delta <0 then 'Приостановка'
		when t.delta_type0 = 'fee_back_from_stop' and t.fee_delta >=0 then 'Возврат с приостановки'
		when t.delta_type0 = 'fee_end' and t.fee_delta <0 then 'Отключение'
		when t.delta_type0 = 'fee_back_from_end' and t.fee_delta >=0 then 'Возврат с отключения'
		when t.delta_type0 = 'fee_pilot_stop' and t.fee_delta >=0 then 'Рост после окончания пилота'
		when t.delta_type0 = 'fee_pilot_stop' and t.fee_delta <0 then 'Снижение после окончания пилота'
		when t.delta_type0 = 'fee_tariff_delta' and t.fee_delta >=0 then 'Положительные изменения в тарифе'
		when t.delta_type0 = 'fee_tariff_delta' and t.fee_delta <0 then 'Отрицательные изменения в тарифе'
		when t.delta_type0 = 'fee_clients_base' and t.fee_delta >=0 then 'Рост клиентской базы'
		when t.delta_type0 = 'fee_clients_base' and t.fee_delta <0 then 'Снижение клиентской базы'
	 else null end as delta_type
	, t.fee_delta
from all_data0 t
where t.fee_delta <> 0)
select
	  t.brand_id
	, t.accountManager as accountManager
	, t.salesManager as salesManager
	, t.projectManager as projectManager
	, t.dt
	, t.delta_type
	, case when t.delta_type in ('Запуск', 'Включение модулей', 'Ручные корректировки вверх', 'Возвращение с интеграции', 
		'Возврат с приостановки', 'Возврат с отключения', 'Рост после окончания пилота', 'Положительные изменения в тарифе', 'Рост клиентской базы') then t.delta_type else null end as delta_type_up
	, case when t.delta_type in ('Отключение модулей', 'Ручные корректировки вниз', 
		'Возврат на интеграцию', 'Приостановка', 'Отключение', 'Снижение после окончания пилота', 'Отрицательные изменения в тарифе', 'Снижение клиентской базы') then t.delta_type else null end as delta_type_down
	, t.fee_delta
from all_data t;

select * from bi_daily_fee_type_dynamic;

--Долги
create live view bi_daily_debt with refresh 14400 as
select
	  brand_id
	, accountManager
	, dt
	, sum(case when status not in ('3','4') and balance < 0 then -balance else 0 end) as debt
	, sum(case when status in ('1') then fee else 0 end) as fee
from bi_daily_fee
group by 1,2,3;

select * from bi_daily_debt;

--Флаги активных менеджеров
create live view bi_daily_active_man_flag with refresh 14400 as
with t as
(select 
	  accountManager
	, dt
	, sum(fee) as fee
from bi_daily_fee
group by 1,2)
select
	  accountManager
	, dt
	, fee
	, case when fee>0 then 1 else 0 end as active_flag
from t;

select * from bi_daily_active_man_flag;

--Таблица по сотрудникам (агрегируем множество метрик)
drop table bi_daily_brand_data;
create live view bi_daily_brand_data with refresh 14400 as
select
	  dfd.brand_id as brand_id
	, JSONExtractString(b.settings, 'archiveReason') as archiveReason
	, dfd.accountManager as accountManager
	, dfd.dt as dt
	, coalesce(damf.active_flag,0) as active_flag
	, dl.status as status
	, df.fee as monthly_fee
	, dfd.fee_delta_all as fee_delta_all
	, dfd.fee_delta as fee_delta
	, dfd.fee_up as fee_up
	, dfd.fee_down as fee_down
	, dl.LTV_on_date as LTV_on_date
	, dl.LT_on_date as LT_on_date
	, dl.LT as LT
	, dl.LTV as LTV
	, dl.LT_account_manager as LT_account_manager
	, dl.LT_sales_manager as LT_sales_manager
	, da.AOV as AOV
	, dd.debt as debt
	, dd.fee as fee_for_debt
	, dc.integration as integration
	, dc.integration_active as integration_active
	, dc.pilot as pilot
	, dc.stopped as stopped
	, dc.lost as lost
	, dc.total as total
	, ds.fee_start_date as fee_start_date
	, case when crm.username is not null then false else true end as active_manager
from bi_daily_fee_dynamic dfd
left join bi_daily_fee df on dfd.brand_id = df.brand_id and dfd.dt = df.dt
left join bi_daily_ltv dl on dfd.brand_id = dl.brand_id and dfd.dt = dl.dt
left join bi_daily_aov da on dfd.brand_id = da.brand_id and dfd.dt = da.dt
left join bi_daily_debt dd on dfd.brand_id = dd.brand_id and dfd.dt = dd.dt
left join bi_daily_clients dc on dfd.brand_id = dc.brand_id and dfd.dt = dc.dt
left join bi_daily_active_man_flag damf on dfd.accountManager = damf.accountManager and dfd.dt = damf.dt
left join brand b on dfd.brand_id = b.globalKey
left join bi_daily_starts ds on dfd.brand_id = ds.brand_id and dfd.dt = ds.dt
left join (select distinct username from crm_operator where isActive = false or isDeleted = true) crm on crm.username = dfd.accountManager;

select * from bi_daily_brand_data;

--Хронология событий по брендам для сотрудников с временем события и аллокацией дневных изменений абонки на события
--Это мы сделали для того, чтобы смотреть все события по дате и времени, которые происходят с брендом
--Есть важный момент в логике, например, у нас бренд отключили 01.10.2024 в 15:00, но при этом на эту дату у него уже было списание абонки
--Мы увидим изменение абонки до нуля от 02.10.2024 и везде в отчётности эта дельта будет второго числа
--При этом в хронологии эта сумма (падение абонки до нуля) будет атрибуцированно к событию первого числа

--Базовая таблица по всем брендам и часам
drop table bi_houry_brand_data;
create live view bi_houry_brand_data with refresh 14400 as
with
toStartOfDay(date('2017-01-01', 'Europe/Moscow')) as dt_start,
toStartOfDay(date(date_trunc('day',now(), 'Europe/Moscow'))) as dt_end,
cal as --календарь по часам
(select 
arrayJoin(arrayMap(x -> toDateTime(x, 'Europe/Moscow'), range(toUInt32(dt_start), toUInt32(dt_end), 3600))) as calday),
brand_list as
(select
	distinct globalKey as brand_id
from brand
where globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')),
all_data0 as
(select 
	bl.brand_id,
	c.calday as dtime
from brand_list bl
cross join cal c),
status_hist as
(select
	  globalKey as brand_id
	, toDateTime(date_trunc('hour',createdAt), 'Europe/Moscow') as dtime
	, status
from brand_status_history)
select
	  a.brand_id as brand_id
	, a.dtime as dtime
	, sh.status as status_chg
	, coalesce(max(case when sh.status in ('1') then dtime else null end) over (partition by a.brand_id, date(a.dtime)), toStartOfDay(a.dtime)+21*3600) as max_dtime_starts
	, coalesce(max(case when sh.status in ('0','5','6') then dtime else null end) over (partition by a.brand_id, date(a.dtime)), toStartOfDay(a.dtime)+21*3600) as max_dtime_toint
	, coalesce(max(case when sh.status in ('3','4') then dtime else null end) over (partition by a.brand_id, date(a.dtime)), toStartOfDay(a.dtime)+21*3600) as max_dtime_losts
	, coalesce(max(case when sh.status in ('2') then dtime else null end) over (partition by a.brand_id, date(a.dtime)), toStartOfDay(a.dtime)+21*3600) as max_dtime_stops
from all_data0 a
left join status_hist sh on sh.brand_id = a.brand_id and sh.dtime = a.dtime;

--События по статусам с изменением абонки
drop table bi_chronology_status_w_fee;
create live view bi_chronology_status_w_fee with refresh 14400 as
with starts as
(select
	  bfd.brand_id as brand_id
	, bfd.dt - 1 as dt
	, case when bfd.accountManager = bfd.salesManager and bfd.accountManager<>'Не назначен' 
			then 'Запуск от обслуживания' else bfd.delta_type end as delta_type
	, bfd.fee_delta as fee_delta
from bi_daily_fee_type_dynamic bfd
where bfd.delta_type='Запуск'),
to_integration as
(select
	  brand_id
	, dt - 1 as dt
	, delta_type
	, fee_delta
from bi_daily_fee_type_dynamic
where delta_type='Возврат на интеграцию'),
back_from_integration as
(select
	  brand_id
	, dt - 1 as dt
	, delta_type
	, fee_delta
from bi_daily_fee_type_dynamic
where delta_type='Возвращение с интеграции'),
stops as
(select
	  brand_id
	, dt - 1 as dt
	, delta_type
	, fee_delta
from bi_daily_fee_type_dynamic
where delta_type='Приостановка'),
back_stops as
(select
	  brand_id
	, dt - 1 as dt
	, delta_type
	, fee_delta
from bi_daily_fee_type_dynamic
where delta_type='Возврат с приостановки'),
losts as
(select
	  brand_id
	, dt - 1 as dt
	, delta_type
	, fee_delta
from bi_daily_fee_type_dynamic
where delta_type='Отключение'),
back_losts as
(select
	  brand_id
	, dt - 1 as dt
	, delta_type
	, fee_delta
from bi_daily_fee_type_dynamic
where delta_type='Возврат с отключения'),
all_data_agr as
(select
	  a.brand_id as brand_id
	, a.dtime as dtime
	, a.max_dtime_starts
	, a.status_chg as status_chg
	, ss.delta_type as delta_type_starts
	, ss.fee_delta as fee_delta_starts
	, ti.delta_type as delta_type_toint
	, ti.fee_delta as fee_delta_toint
	, bi.delta_type as delta_type_back_fromint
	, bi.fee_delta as fee_delta_back_fromint
	, ls.delta_type as delta_type_losts
	, ls.fee_delta as fee_delta_losts
	, st.delta_type as delta_type_stops
	, st.fee_delta as fee_delta_stops
	, bs.delta_type as delta_type_back_stops
	, bs.fee_delta as fee_delta_back_stops
	, bl.delta_type as delta_type_back_losts
	, bl.fee_delta as fee_delta_back_losts
from bi_houry_brand_data a
left join starts ss on ss.brand_id = a.brand_id and ss.dt = date(a.dtime) and a.dtime = a.max_dtime_starts and (a.status_chg = '1' or a.status_chg is null)
left join to_integration ti on ti.brand_id = a.brand_id and ti.dt = date(a.dtime) and a.dtime = a.max_dtime_toint and (a.status_chg = '0' or a.status_chg = '5' or a.status_chg is null)
left join back_from_integration bi on bi.brand_id = a.brand_id and bi.dt = date(a.dtime) and a.dtime = a.max_dtime_starts and (a.status_chg = '1' or a.status_chg is null)
left join losts ls on ls.brand_id = a.brand_id and ls.dt = date(a.dtime) and a.dtime = a.max_dtime_losts and (a.status_chg in ('3','4') or a.status_chg is null)
left join stops st on st.brand_id = a.brand_id and st.dt = date(a.dtime) and a.dtime = a.max_dtime_stops and (a.status_chg = '2' or a.status_chg is null)
left join back_stops bs on bs.brand_id = a.brand_id and bs.dt = date(a.dtime) and a.dtime = a.max_dtime_starts and (a.status_chg = '1' or a.status_chg is null)
left join back_losts bl on bl.brand_id = a.brand_id and bl.dt = date(a.dtime) and a.dtime = a.max_dtime_starts and (a.status_chg = '1' or a.status_chg is null)),
t as
(select
	  brand_id
	, dtime
	, coalesce(delta_type_starts,
		coalesce(delta_type_toint,
			coalesce(delta_type_back_fromint,
				coalesce(delta_type_stops,
					coalesce(delta_type_losts,
						coalesce(delta_type_back_stops,delta_type_back_losts)))))) as action_type
	, toInt64(coalesce(fee_delta_starts,
		coalesce(fee_delta_toint,
			coalesce(fee_delta_back_fromint,
				coalesce(fee_delta_stops,
					coalesce(fee_delta_losts,
						coalesce(fee_delta_back_stops,fee_delta_back_losts))))))) as fee_delta
from all_data_agr a)
select
	  distinct
	  brand_id
	, dtime
	, action_type
	, fee_delta
from t
where
action_type is not null;

--События по статусам без изменения абонки
drop table bi_chronology_status_wo_fee;
create live view bi_chronology_status_wo_fee with refresh 14400 as
select
	  t.brand_id
	, t.dtime
	, case
		when t.status_chg = '0' then 'Изменён статус На интеграции'
		when t.status_chg = '5' then 'Изменён статус Подготовка к запуску'
		when t.status_chg = '1' then 'Изменён статус Активен'
		when t.status_chg = '2' then 'Изменён статус Приостановлен'
		when t.status_chg = '3' then 'Изменён статус Архивный'
		when t.status_chg = '4' then 'Изменён статус Удалён'
		when t.status_chg = '6' then 'Изменён статус Возврат в продажи'
	  else 'Не известный статус' end as action_type
	, toInt64(0) as fee_delta
from bi_houry_brand_data t
left join bi_chronology_status_w_fee f on f.brand_id = t.brand_id and f.dtime = t.dtime
where t.status_chg is not null and f.brand_id is null;

select * from bi_chronology_status_wo_fee;

--События по модулям
drop table bi_chronology_moduls;
create live view bi_chronology_moduls with refresh 14400 as
with moduls00 as
(select
      bph.globalKey as brand_id
    , bph.createdAt
    , JSONExtractString(opt_unnest, 'name') as fee_type
    , sum(JSONExtractFloat(opt_unnest, 'monthly')) as fee_value 
from default.brand_price_history bph
    array join JSONExtractArrayRaw(coalesce(bph.price_options, '[]')) as opt_unnest
group by 1,2,3),
moduls0 as
(select
	  brand_id
	, toDateTime(date_trunc('hour',createdAt), 'Europe/Moscow') as dtime
	, fee_type
	, fee_value
	, fee_value - 
	  coalesce(any(fee_value) 
		over (partition by brand_id, fee_type order by createdAt rows between 1 preceding and 1 preceding),0) as fee_delta
	, any(fee_type) over (partition by brand_id, fee_type order by createdAt rows between 1 preceding and 1 preceding) as fee_type_old
from moduls00),
moduls as
(select
	  brand_id
	, dtime
	, fee_type
	, any(dtime) over (partition by brand_id, fee_type order by dtime rows between 1 preceding and 1 preceding) as dtime_old
	, fee_delta
from moduls0
where not(fee_delta = 0 and fee_type = fee_type_old)),
moduls_days as
(select 
	  m.brand_id
	, m.dtime
	, m.fee_type
	, sum(case when f.fee>0 then 1 else 0 end) as days_w_module
from moduls m
left join bi_daily_fee f on f.brand_id = m.brand_id
where m.fee_delta<0 
	and f.dt >= (case when m.dtime_old::date<'2022-10-01'::date then '2022-10-01'::date else m.dtime_old::date end) 
	and f.dt<m.dtime::date
group by 1,2,3),
fee_moduls as
(select
	  brand_id
	, dt - 1 as dt
	, delta_type
	, fee_delta
from bi_daily_fee_type_dynamic
where delta_type in ('Включение модулей','Отключение модулей')),
t as
(select
	  a.brand_id as brand_id
	, a.dtime as dtime
	, m.fee_type as fee_type
	, fm.fee_delta * m.fee_delta / nullif(sum(m.fee_delta) over (partition by a.brand_id, fm.dt),0) as fee_delta
from bi_houry_brand_data a
left join moduls m on m.brand_id = a.brand_id and m.dtime = a.dtime
left join fee_moduls fm on fm.brand_id = a.brand_id and fm.dt = date(a.dtime))
select
	  t.brand_id
	, t.dtime
	, case when fee_delta >=0 then concat('Вкл модуль ',t.fee_type) 
		else concat('Выкл модуль ',t.fee_type,
			case when coalesce(md.days_w_module,0)>0 then concat(' (',md.days_w_module::text,' дн.)') else '' end) end as action_type
	, toInt64(t.fee_delt) as fee_delta
from t
left join moduls_days md on md.brand_id = t.brand_id and md.dtime = t.dtime and md.fee_type = t.fee_type
where t.fee_delta is not null;

--События по ручным корректировкам
drop table bi_chronology_hand_corr;
create live view bi_chronology_hand_corr with refresh 14400 as
with t00 as
(select
      bph.globalKey as brand_id
    , date_trunc('hour',bph.createdAt, 'Europe/Moscow') as dtime
    , toInt64(JSONExtractString(prc_unnest, 'clients')) as clients
    , JSONExtractFloat(prc_unnest, 'monthly') as fee_value
from default.brand_price_history bph
    array join JSONExtractArrayRaw(coalesce(bph.price_perClient, '[]')) as prc_unnest),
t0 as
(select
	  brand_id
	, dtime
	, fee_value
	, fee_value - any(fee_value) over (partition by brand_id, clients order by dtime rows between 1 preceding and 1 preceding) as fee_delta
from t00
where brand_id not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')),
t as
(select
	  brand_id
	, dtime
	, case when fee_delta > 0 then 'Ручные корректировки вверх' else 'Ручные корректировки вниз' end as delta_type
	, fee_delta as fee_delta_t
from t0
where fee_delta <> 0 and fee_delta <> fee_value),
fee_day as
(select
	  brand_id
	, dt - 1 as dt
	, delta_type
	, fee_delta
from bi_daily_fee_type_dynamic
where delta_type in ('Ручные корректировки вверх','Ручные корректировки вниз'))
select
	  t.brand_id
	, t.dtime
	, t.delta_type as action_type
	, toInt64(coalesce(f.fee_delta * t.fee_delta_t / nullif(sum(t.fee_delta_t) over (partition by t.brand_id, f.dt),0),0)) as fee_delta
from t
left join fee_day f on f.brand_id = t.brand_id and f.dt = date(t.dtime);

--События по окончанию пилота
drop table bi_chronology_pilot_stop;
create live view bi_chronology_pilot_stop with refresh 14400 as
select
	  brand_id
	, toDateTime(dt - 1) as dtime
	, delta_type as action_type
	, toInt64(fee_delta) as fee_delta
from bi_daily_fee_type_dynamic
where delta_type in ('Рост после окончания пилота','Снижение после окончания пилота');

select * from bi_chronology_pilot_stop;

--События по изменению тарифа
drop table bi_chronology_tariffs;
create live view bi_chronology_tariffs with refresh 14400 as
with t0 as
(select 
	  brand_id
	, dt
	, tariff_name
	, any(tariff_name) over (partition by brand_id, tariff_module_name order by dt rows between 1 preceding and 1 preceding) as tariff_name_before
	, tariff_module_name
	, discount_value
	, any(discount_value) over (partition by brand_id, tariff_module_name order by dt rows between 1 preceding and 1 preceding) as discount_value_before
	, tariff_fee
	, any(tariff_fee) over (partition by brand_id, tariff_module_name order by dt rows between 1 preceding and 1 preceding) as tariff_fee_before	
from bi_daily_tariff_module),
t as 
(select
	  brand_id
	, dt
	, tariff_name
	, tariff_name_before
	, tariff_module_name
	, tariff_fee
	, tariff_fee_before
	, case when tariff_fee <> tariff_fee_before then
		case 
			when tariff_fee_before = 0 then concat('Включение модуля ', tariff_module_name
				, case when discount_value is not null then concat(' (скидка ',discount_value,')') else 
					case when discount_value_before is not null then ' (отмена скидки)' else '' end end)
			when tariff_fee = 0 then concat('Отключение модуля ', tariff_module_name)
			when tariff_name <> tariff_name_before then concat('Смена тарифа ',tariff_name_before,' -> ',tariff_name,' по модулю ',tariff_module_name
				, case when discount_value is not null then concat(' (скидка ',discount_value,')') else
					case when discount_value_before is not null then ' (отмена скидки)' else '' end end)
		 else concat('Изменение стоимости модуля ', tariff_module_name
		 	, case when discount_value is not null then concat(' (скидка ',discount_value,')') else 
		 		case when discount_value_before is not null then ' (отмена скидки)' else '' end end) end
	  else null end as delta_type
from t0),
delta_types as
(select
	  brand_id
	, dt
	, arrayStringConcat(groupArray(delta_type),' | ') as delta_type
from t
where t.delta_type is not null
group by 1,2)
select
	  d.brand_id
	, toDateTime(d.dt - 1) as dtime
	, coalesce(dt.delta_type, d.delta_type) as action_type
	, toInt64(d.fee_delta) as fee_delta
from bi_daily_fee_type_dynamic d
left join delta_types dt on dt.brand_id = d.brand_id and dt.dt = d.dt
where d.delta_type in ('Положительные изменения в тарифе','Отрицательные изменения в тарифе');

select * from bi_chronology_tariffs;

--События по изменению клиентской базы
drop table bi_chronology_clients;
create live view bi_chronology_clients with refresh 14400 as
select
	  brand_id
	, toDateTime(dt - 1) as dtime
	, delta_type as action_type
	, toInt64(fee_delta) as fee_delta
from bi_daily_fee_type_dynamic
where delta_type in ('Рост клиентской базы','Снижение клиентской базы');

select * from bi_chronology_clients;

--Объединённая таблица (запрос для DataLens)
--with temp_t as ()
with u_all as
(select * from default.bi_chronology_status_w_fee
union all
select * from default.bi_chronology_status_wo_fee
union all
select * from default.bi_chronology_moduls
union all
select * from default.bi_chronology_hand_corr
union all
select * from default.bi_chronology_pilot_stop
union all
select * from default.bi_chronology_tariffs
union all
select * from default.bi_chronology_clients)
select
	  u.dtime as dtime
    , toDate(u.dtime) + 1 as dt_debit
	, case
		when f.status = '0' then 'На интеграции'
		when f.status = '5' then 'Подготовка к запуску'
		when f.status = '1' then 'Активен'
		when f.status = '2' then 'Приостановлен'
		when f.status = '3' then 'Архивный'
		when f.status = '4' then 'Удалён'
		when f.status = '6' then 'Возврат в продажи'
	  else 'Не известный' end as status
	, coalesce(b.name,'N/A') as brand
	, u.brand_id as brand_id
	, l.LTV_on_date as LTV
	, l.LT_on_date as LT
	, f.fee as fee
	, u.fee_delta as fee_delta
	, u.action_type as action_type
	, coalesce(bbm.accountManager,'Не назначен') as accountManager
	, coalesce(bbm.salesManager,'Не назначен') as salesManager
	, coalesce(bbm.projectManager,'Не назначен') as projectManager
from u_all u
left join default.brand b on b.globalKey = u.brand_id
left join default.bi_daily_fee f on f.brand_id = u.brand_id and f.dt = date(u.dtime) + 1
left join default.bi_daily_fee f1 on f1.brand_id = u.brand_id and f1.dt = date(u.dtime)
left join default.bi_daily_ltv l on l.brand_id = u.brand_id and l.dt = date(u.dtime)
left join default.bi_brand_managers bbm on bbm.brand_id = u.brand_id and bbm.dt = date(u.dtime)
order by 3, 1;

--Определение границ для среднего чека
with t as
(select
	  globalKey 
	, avg(paidAmount) as aov
from purchase
where createdAt >= '2023-01-01'
group by 1)
select
	  quantile(0.1)(aov) as q0
	, quantile(0.25)(aov) as q1
	, quantile(0.5)(aov) as q2
	, quantile(0.75)(aov) as q3
	, quantile(0.90)(aov) as q4
from t; 
--q1 1000
--q2 3000
--q3 8000
--qP 20000
select * from bi_product_target_group;


--Таблица для борда Продукт / Целевая аудитория
drop table bi_product_target_group;
create live view bi_product_target_group with refresh 14400 as
with b00 as
(select
	  globalKey as brand_id
	, name
	, case when defaultCountry = 'kz' then true else false end as kz_type --Флаг Казахстана
	, JSONExtractString(extraFields, 'industry') as industry_arr
	, JSONExtractString(extraFields, 'posSoftware') as soft_arr 
from brand),
b0 as
(select
	  brand_id
	, name
	, kz_type
	, replaceAll(ind,'"','') as industry
	, soft_arr 
from b00
	array join JSONExtractArrayRaw(coalesce(industry_arr, '[]')) as ind),
b as
(select
	  brand_id
	, name
	, kz_type
	, industry
	, replaceAll(sft,'"','') as soft
from b0
	array join JSONExtractArrayRaw(coalesce(soft_arr, '[]')) as sft),
shops as
(select
	  globalKey as brand_id
	, count(*) as shops_qty
from shop
where isActive = true
group by 1),
rev_type as
(select
	  globalKey as brand_id
	, case 
		when 30 * sum(paidAmount)/(max(createdAt)::date - min(createdAt)::date + 1) < 1500000 then 'до 1,5 млн.'
		when 30 * sum(paidAmount)/(max(createdAt)::date - min(createdAt)::date + 1) < 5000000 then '1,5 - 5 млн.'
		when 30 * sum(paidAmount)/(max(createdAt)::date - min(createdAt)::date + 1) < 10000000 then '5 - 10 млн.'
		when 30 * sum(paidAmount)/(max(createdAt)::date - min(createdAt)::date + 1) < 25000000 then '10 - 25 млн.'
		when 30 * sum(paidAmount)/(max(createdAt)::date - min(createdAt)::date + 1) < 100000000 then '25 - 100 млн.'
		else 'более 100 млн.'
	  end as rev_type
from purchase --это таблица с продажами брендов, она собирается из интеграции кассового ПО и Maxma, то есть мы знаем выручку брендов
group by 1),
aov_type as --средний чек по продажам бренда (границы определили через статистику по квартилям)
(select
	  globalKey as brand_id
	, case 
		when avg(paidAmount) < 1000 then 'до 1000 руб.'
		when avg(paidAmount) < 3000 then '1000 руб. - 3000 руб.'
		when avg(paidAmount) < 8000 then '3000 руб. - 8000 руб.'
		when avg(paidAmount) < 20000 then '8000 руб. - 20000 руб.'
		else 'более 20000 руб.'
	  end as aov_type
from purchase
group by 1),
gain_lost as
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) as dt
	, sum(coalesce(paidAmount,0)) as gain_sum
	, sum(coalesce(offerDiscount,0) + coalesce(promocodeDiscount,0) + coalesce(bonusesDiscount,0)) as lost_sum
	, count(paidAmount) as orders_qty
from purchase
group by 1,2),
lost_m as --сумма, которую бренд платит за Maxma
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',billedAt), 'Europe/Moscow')) as dt
	, sum(statAmount) as lost_maxma
from expense
group by 1,2),
site_brand as --Флаг для бренда, который является интернет-магазином
(select 
  brand_id
, case when sum(case when soft<>'Сайт' then 1 else 0 end) = 0 and sum(case when soft='Сайт' then 1 else 0 end)>0 then true else false end site_flg
from b 
group by 1)
select
	  df.brand_id as brand_id
	, br.name as name
	, b.industry as industry
	, case when b.soft = '1C' or b.soft = '1С' then '1C' else b.soft end as soft
	, case 
		when sb.site_flg = true then 'Только сайт'
		when b.kz_type = true then 'Казахстан'
		else r.rev_type
	  end as rev_type
	, a.aov_type as aov_type
	, s.shops_qty as shops_qty
	, df.dt as dt
	, df.status as status
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else df.daily_fee end as daily_fee
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else df.fee end as fee
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else fd.fee_up end as fee_up
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else fd.fee_down end as fee_down
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else dl.LTV end as LTV
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else dl.LTV_on_date end as LTV_on_date
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else vs.v_start_days end as start_days
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else coalesce(gl.gain_sum,0) end as gain_sum
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else coalesce(gl.lost_sum,0) + coalesce(lm.lost_maxma,0) end as lost_sum
	, case when df.status = 0 or df.status = 5 or df.status = 6 then null else coalesce(gl.orders_qty,0) end as orders_qty
from bi_daily_fee df
left join brand br on br.globalKey = df.brand_id
left join bi_daily_fee_dynamic fd on fd.brand_id = df.brand_id and fd.dt = df.dt
left join bi_daily_ltv dl on df.brand_id = dl.brand_id and df.dt = dl.dt
left join bi_daily_v_start vs on df.brand_id = vs.brand_id and df.dt = vs.dt
left join b on b.brand_id = df.brand_id
left join shops s on s.brand_id = df.brand_id
left join rev_type r on r.brand_id = df.brand_id
left join aov_type a on a.brand_id = df.brand_id
left join gain_lost gl on gl.brand_id = df.brand_id and gl.dt = df.dt
left join lost_m lm on lm.brand_id = df.brand_id and lm.dt = df.dt
left join site_brand sb on sb.brand_id = df.brand_id;

select * from bi_product_target_group;

--- По индустриям (эти таблицы делаем для BI, так как у бренда одного может быть несколько индустрий и ПО, мы для разных разрезов делаем дедуплицированные таблицы)
drop table bi_product_target_group_industry;
create live view bi_product_target_group_industry with refresh 14400 as
select
      brand_id
    , name
    , industry
    , 0 as shops_qty
    , dt
    , status
    , arrayStringConcat(groupUniqArray(soft),', ') as soft
    , arrayStringConcat(groupUniqArray(rev_type),', ') as rev_type
    , arrayStringConcat(groupUniqArray(aov_type),', ') as aov_type
    , avg(daily_fee) as daily_fee
    , avg(fee) as fee
    , avg(fee_up) as fee_up
    , avg(fee_down) as fee_down
    , avg(LTV) as LTV
    , avg(LTV_on_date) as LTV_on_date
    , avg(start_days) as start_days
    , avg(gain_sum) as gain_sum
    , avg(lost_sum) as lost_sum
    , avg(orders_qty) as orders_qty
from bi_product_target_group
group by 1,2,3,4,5,6;

select * from bi_product_target_group_industry;
-------------

--
--Запущенные механики
--
--Бренды запускают различные акции, рассылки разного рода


--Рассылки
create live view bi_mechanics_sendings with refresh 14400 as
with mb_rec0 as
(select
	  globalKey 
	, id
	, JSONExtractString(recipients, 'all') as all_flg
	, JSONExtractString(JSONExtractString(recipients, 'filters'),'configuration') as extr
from mailing_brand), --таблица с рассылками
mb_rec as
(select
	  mb.globalKey 
	, mb.id
	, max(case when mb.all_flg = 'true' then 'Все сегменты'
		else JSONExtractString(extr_parse,'text') end) as recipients --кому идёт рассылка
from mb_rec0 mb
left array join JSONExtractArrayRaw(coalesce(mb.extr, '[]')) as extr_parse
group by 1,2),
moff as
(select
	  distinct
	  globalKey
	, mailingBrandId
from mailing_offer),
sendings as
(select
	  globalKey
	, mailingBrandId
	, count(distinct clientId) as sended
	, count(distinct case when delivered = true then clientId else null end) as deivered --доставлено
	, count(distinct case when openedAt is not null then clientId else null end) as opened --открыли рассылку
	, count(distinct case when unsubscribed = true then clientId else null end) as unsubscribed --отписались от рассылки
from mailing_sending
group by 1,2),
promo as --данные по промокодам
(select
	  globalKey
	, id as promocodeId
	, max(discountAmount) as promocode_disc
from promocode
group by 1,2),
off as --данные по акциям
(select
	  o.globalKey as globalKey
	, mo.mailingBrandId as mailingBrandId
	, max(o.discountAmount) as off_disc
from offer o
left join mailing_offer mo on mo.globalKey = o.globalKey and mo.offerId = o.id
group by 1,2),
gain_lost as
(select
	  globalKey
	, mailingBrandId
	, max(createdAt) as last_sale_dt
	, sum(case when coalesce(paidAmount,0)>0 then 1 else 0 end) as orders --число покупок бренда
	, sum(coalesce(paidAmount,0)) as gain_sum
	, sum(coalesce(offerDiscount,0) + coalesce(promocodeDiscount,0) + coalesce(bonusesDiscount,0)) as lost_sum --расходы бренда
from purchase --продажи бренда
where mailingBrandId is not null
group by 1,2),
lost_m as --затраты бренда на Maxma
(select
	  globalKey
	, mailingBrandId
	, sum(coalesce(statAmount,0)) as lost_maxma
from expense
where mailingBrandId is not null and operation>0
group by 1,2)
select
	  case 
		when m.type = 0 then 'Автоматические рассылки'
		when m.type = 1 then 'Ручные рассылки'
	  end as module_type --рассылки могут быть автоматическими по триггерам (например, день рождения, брошенная корзина и т.п.) и ручными с настройками
	, m.globalKey as brand_id
	, case 
		when m.type = 0 then m.createdAt+3*3600
		when m.type = 1 then coalesce(m.scheduledAt+3*3600,m.createdAt+3*3600)
	  end as dtime
	, gl.last_sale_dt+3*3600 as last_sale_dt
	, case
		when m.type = 1 and m.triggerType in (0) then 'Без триггера'
		when m.triggerType in (8,9,10,11) then 'Брошенные корзины'
		when m.triggerType in (0) then 'Переход в сегмент'
		when m.triggerType in (1) then 'Выход из сегмента'
		when m.triggerType in (2) then 'Активация бонуса'
		when m.triggerType in (3) then 'Возврат покупки'
		when m.triggerType in (4) then 'День Рождения'
		when m.triggerType in (5) then 'Сгорание бонуса'
		when m.triggerType in (6) then 'Покупка'
		when m.triggerType in (7) then 'День Рождения ребёнка'
		when m.triggerType in (12) then 'Регистрация клиента'
		when m.triggerType in (13) then 'Установка Wallet-карты'
		when m.triggerType in (14) then 'Подписка на Email-рассылку'
		when m.triggerType in (15) then 'По расписанию'
		when m.triggerType in (16) then 'Повышение уровня в ПЛ'
		when m.triggerType in (17) then 'Получение Email-рассылки'
		else 'Без триггера'
	  end as trigger_type
	, m.name as name
	, concat(
		  case when m.bonuses>0 then 'Бонусы' else '' end
		, case when m.bonuses>0 and (m.promocodeId is not null or moff.globalKey is not null) then ', ' else '' end
		, case when m.promocodeId is not null then 'Промокод' else '' end
		, case when (m.bonuses>0 or m.promocodeId is not null) and moff.globalKey is not null then ', ' else '' end
		, case when moff.globalKey is not null then 'Акция' else '' end) as offer_type
	, case 
		when m.bonuses>0 then m.bonuses
		when coalesce(p.promocode_disc,0)>0 then p.promocode_disc 
		when coalesce(o.off_disc,0)>0 then o.off_disc
	  else 0 end as offer_value
	, extractTextFromHTML(mr.recipients) as recipients
	, coalesce(s.sended,0) as sended
	, coalesce(s.deivered,0) as delivered
	, coalesce(s.opened,0) as opened
	, coalesce(s.unsubscribed,0) as unsubscribed
	, concat(
		  case when JSONExtractString(channels, 'sms') = 'true' then 'SMS' else '' end
		, case when JSONExtractString(channels, 'sms') = 'true' and JSONExtractString(channels, 'push') = 'true' then ', ' else '' end
		, case when JSONExtractString(channels, 'push') = 'true' then 'Push' else '' end
		, case when (JSONExtractString(channels, 'sms') = 'true' or JSONExtractString(channels, 'push') = 'true') 
			and JSONExtractString(channels, 'viber') = 'true' then ', ' else '' end
		, case when JSONExtractString(channels, 'viber') = 'true' then 'Viber' else '' end
		, case when (JSONExtractString(channels, 'sms') = 'true' or JSONExtractString(channels, 'push') = 'true' or JSONExtractString(channels, 'viber') = 'true') 
			and JSONExtractString(channels, 'email') = 'true' then ', ' else '' end
		, case when JSONExtractString(channels, 'email') = 'true' then 'E-Mail' else '' end
	  ) as channels --каналы рассылки
	, m.rawSmsBody as sms_body
	, m.rawPushBody as push_body
	, m.rawViberBody as viber_body
	, m.emailPreviewImageUrl as email_url
	, coalesce(gl.orders,0) as orders
	, coalesce(gl.gain_sum,0) as revenue
	, coalesce(gl.lost_sum,0) as disc_lost
	, coalesce(lm.lost_maxma,0) as maxma_lost
from mailing_brand m
left join moff on moff.globalKey = m.globalKey and moff.mailingBrandId = m.id
left join sendings s on s.globalKey = m.globalKey and s.mailingBrandId = m.id
left join promo p on p.globalKey = m.globalKey and p.promocodeId = m.promocodeId
left join off o on o.globalKey = m.globalKey and o.mailingBrandId = m.id
left join gain_lost gl on gl.globalKey = m.globalKey and gl.mailingBrandId = m.id
left join lost_m lm on lm.globalKey = m.globalKey and lm.mailingBrandId = m.id
left join mb_rec mr on mr.id = m.id and mr.globalKey = m.globalKey
where m.isDeleted = false
and m.globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40');

select * from bi_mechanics_sendings;

--Инструменты Акции
--Смотрим все метрики в разрезе конкретных акций бренда
create live view bi_mechanics_tools_promo with refresh 14400 as
with off_rec0 as
(select
	  globalKey 
	, id
	, JSONExtractString(recipients, 'all') as all_flg
	, JSONExtractString(JSONExtractString(recipients, 'filters'),'configuration') as extr
from offer),
off_rec as
(select
	  off.globalKey 
	, off.id
	, max(case when off.all_flg = 'true' then 'Все сегменты'
		else JSONExtractString(extr_parse,'text') end) as recipients
from off_rec0 off
left array join JSONExtractArrayRaw(coalesce(off.extr, '[]')) as extr_parse
group by 1,2),
po_promo as
(select
	  distinct
	  po.globalKey as globalKey
	, po.purchaseId as purchaseId
	, o.createdAt as dtime
	, o.title as name
	, extractTextFromHTML(offr.recipients) as recipients
from purchase_offer po
join offer o on o.globalKey = po.globalKey and o.id = po.offerId
left join off_rec offr on offr.globalKey = o.globalKey and offr.id = o.id
where o.isDeleted = false),
purch_promo as
(select
	  p.globalKey as globalKey 
	, po.dtime as dtime
	, po.recipients as recipients
	, coalesce(po.name,'Без названия') as name
	, max(p.createdAt) as last_sale_dt
	, sum(case when coalesce(p.paidAmount,0)>0 then 1 else 0 end) as orders
	, sum(coalesce(p.paidAmount,0)) as revenue
	, sum(coalesce(p.offerDiscount,0) + coalesce(p.promocodeDiscount,0) + coalesce(p.bonusesDiscount,0)) as disc_lost
from purchase p
left join po_promo po on po.purchaseId = p.id and po.globalKey = p.globalKey
where p.globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')
group by 1,2,3,4)
select 
	  'Акции' as module_type
	, p.globalKey as brand_id
	, p.dtime+3*3600  as dtime
	, p.last_sale_dt+3*3600  as last_sale_dt
	, 'Без триггера' as trigger_type
	, p.name as name
	, null as offer_type
	, null as offer_value
	, p.recipients as recipients
	, null as sended
	, null as delivered
	, null as opened
	, null as unsubscribed
	, null as channels
	, null as sms_body
	, null as push_body
	, null as viber_body
	, null as email_url
	, p.orders as orders
	, p.revenue as revenue
	, p.disc_lost as disc_lost
	, 0 as maxma_lost
from purch_promo p;

select * from bi_mechanics_tools_promo;

--Инструменты Промокоды (аналогично срез по промокодам, они могут быть и в рассылках и т.д.)
create live view bi_mechanics_tools_promocodes with refresh 14400 as
with pm as
(select
	  distinct
	  globalKey
	, id as promocodeId
	, createdAt as dtime
	, code as name
from promocode
where codeType in (0,1) and isDeleted = false),
purch_pcode as
(select
	  p.globalKey as globalKey
	, pm.dtime as dtime
	, coalesce(pm.name,'Без названия') as name
	, max(p.createdAt) as last_sale_dt
	, sum(case when coalesce(p.paidAmount,0)>0 then 1 else 0 end) as orders
	, sum(coalesce(p.paidAmount,0)) as revenue
	, sum(coalesce(p.offerDiscount,0) + coalesce(p.promocodeDiscount,0) + coalesce(p.bonusesDiscount,0)) as disc_lost
from purchase p
join pm on pm.promocodeId = p.promocodeId and pm.globalKey = p.globalKey
where p.globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')
group by 1,2,3)
select 
	  'Промокоды' as module_type
	, p.globalKey as brand_id
	, p.dtime+3*3600 as dtime
	, p.last_sale_dt+3*3600 as last_sale_dt
	, 'Без триггера' as trigger_type
	, p.name as name
	, null as offer_type
	, null as offer_value
	, null as recipients
	, null as sended
	, null as delivered
	, null as opened
	, null as unsubscribed
	, null as channels
	, null as sms_body
	, null as push_body
	, null as viber_body
	, null as email_url
	, p.orders as orders
	, p.revenue as revenue
	, p.disc_lost as disc_lost
	, 0 as maxma_lost
from purch_pcode p;

select * from bi_mechanics_tools_promocodes;

--Инструменты Приведи друга (специальный тип промокодов)
create live view bi_mechanics_tools_friend with refresh 14400 as
with pm_f as
(select
	  distinct
	  globalKey
	, id as promocodeId
	, createdAt as dtime
	, code as name
from promocode
where codeType = 2 and isDeleted = false),
purch_friend as
(select
	  p.globalKey as globalKey
	, pm_f.dtime as dtime
	, coalesce(pm_f.name,'Без названия') as name
	, max(p.createdAt) as last_sale_dt
	, sum(case when coalesce(p.paidAmount,0)>0 then 1 else 0 end) as orders
	, sum(coalesce(p.paidAmount,0)) as revenue
	, sum(coalesce(p.offerDiscount,0) + coalesce(p.promocodeDiscount,0) + coalesce(p.bonusesDiscount,0)) as disc_lost
from purchase p
join pm_f pm on pm.promocodeId = p.promocodeId and pm.globalKey = p.globalKey
where p.globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')
group by 1,2,3)
select 
	  'Приведи друга' as module_type
	, p.globalKey as brand_id
	, p.dtime+3*3600 as dtime
	, p.last_sale_dt+3*3600 as last_sale_dt
	, 'Без триггера' as trigger_type
	, p.name as name
	, null as offer_type
	, null as offer_value
	, null as recipients
	, null as sended
	, null as delivered
	, null as opened
	, null as unsubscribed
	, null as channels
	, null as sms_body
	, null as push_body
	, null as viber_body
	, null as email_url
	, p.orders as orders
	, p.revenue as revenue
	, p.disc_lost as disc_lost
	, 0 as maxma_lost
from purch_friend p;

select * from bi_mechanics_tools_friend;

--Инструменты Подарочные карты (аналитика подарочных карт / сертификатов)
create live view bi_mechanics_tools_giftcard with refresh 14400 as
with gc as
(select
	  distinct
	  ga.globalKey as globalKey
	, ga.purchaseId as purchaseId
	, g.createdAt as dtime
	, g.name as name
from gift_card_applied ga
left join gift_card g on g.id = ga.id and g.globalKey = ga.globalKey
where g.isDeleted = false),
purch_gift as
(select
	  p.globalKey as globalKey
	, gc.dtime as dtime
	, coalesce(gc.name,'Без названия') as name
	, max(p.createdAt) as last_sale_dt
	, sum(case when coalesce(p.paidAmount,0)>0 then 1 else 0 end) as orders
	, sum(coalesce(p.paidAmount,0)) as revenue
	, sum(coalesce(p.offerDiscount,0) + coalesce(p.promocodeDiscount,0) + coalesce(p.bonusesDiscount,0)) as disc_lost
from purchase p
join gc on gc.purchaseId = p.id and gc.globalKey = p.globalKey
where p.globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')
group by 1,2,3)
select 
	  'Подарочные карты' as module_type
	, p.globalKey as brand_id
	, p.dtime+3*3600 as dtime
	, p.last_sale_dt+3*3600 as last_sale_dt
	, 'Без триггера' as trigger_type
	, p.name as name
	, null as offer_type
	, null as offer_value
	, null as recipients
	, null as sended
	, null as delivered
	, null as opened
	, null as unsubscribed
	, null as channels
	, null as sms_body
	, null as push_body
	, null as viber_body
	, null as email_url
	, p.orders as orders
	, p.revenue as revenue
	, p.disc_lost as disc_lost
	, 0 as maxma_lost
from purch_gift p;

select * from bi_mechanics_tools_giftcard;

--Скрипт для отчёта по механикам (сводим все маркетинговые активности)
with all_data as
(select * from default.bi_mechanics_sendings
union all
select * from default.bi_mechanics_tools_promo
union all
select * from default.bi_mechanics_tools_promocodes
union all
select * from default.bi_mechanics_tools_friend
union all
select * from default.bi_mechanics_tools_giftcard
),
b_data_base as
(select
	  brand_id
	, accountManager
	, case
		when status = '0' then 'На интеграции'
		when status = '5' then 'Подготовка к запуску'
		when status = '1' then 'Активен'
		when status = '2' then 'Приостановлен'
		when status = '3' then 'Архивный'
		when status = '4' then 'Удалён'
		when status = '6' then 'Возврат в продажи'
	  else 'Не известный' end as status
from default.bi_daily_fee
where dt = (select max(dt) as mdt from default.bi_daily_fee)),
b_data_add_raw as
(select
	  distinct
	  brand_id
	, rev_type
	, industry
from default.bi_product_target_group
order by 1,3),
b_data_add as
(select
	  brand_id
	, coalesce(rev_type, 'Нет данных') as rev_type
	, case when arrayStringConcat(groupArray(industry),' | ') = '' then 'Нет данных'
		else arrayStringConcat(groupArray(industry),' | ') end as industry
from b_data_add_raw
group by 1,2)
select
	  a.module_type as module_type
	, b.name as brand_name
	, bdb.status as status
	, bdb.accountManager as current_manager
	, bda.rev_type as rev_type
	, bda.industry as industry
	, a.dtime as dtime
	, a.last_sale_dt as last_sale_dt
	, a.trigger_type as trigger_type
	, a.name as name
	, a.offer_type as offer_type
	, a.offer_value as offer_value
	, a.recipients as recipients
	, a.sended as sended
	, a.delivered as delivered
	, a.opened as opened
	, a.unsubscribed as unsubscribed
	, a.channels as channels
	, a.sms_body as sms_body
	, a.push_body as push_body
	, a.viber_body as viber_body
	, a.email_url as email_url
	, a.orders as orders
	, a.revenue as revenue
	, a.disc_lost as disc_lost
	, a.maxma_lost as maxma_lost
from all_data a
left join default.brand b on b.globalKey = a.brand_id
left join b_data_base bdb on bdb.brand_id = a.brand_id
left join b_data_add bda on bda.brand_id = a.brand_id;



--
-- Отчет по сервисам рассылок
--
--Статичный отчёт, чтобы следить за конкретными рассылками (без данных об эффективности)
drop table bi_sendings_services;
create live view bi_sendings_services with refresh 14400 as
select
	  globalKey as brand_id
	, name as brand_name
	, case status
		when 0 then 'На интеграции'
		when 5 then 'Подготовка к запуску'
		when 1 then 'Активен'
		when 2 then 'Приостановлен'
		when 3 then 'Архивный'
		when 4 then 'Удалён'
		when 6 then 'Возврат в продажи'
	  else 'Не известный' end as status
	, JSONExtractString(settings, 'inn') as inn
	, JSONExtractString(JSONExtractString(settings, 'accountManager'),'username') as accountManager
	, case JSONExtractString(settings, 'smsProvider')
		when 'builtin' then 'BuiltIn'
		when 'smpp' then 'SMPP'
		when 'smsaero' then 'SmsAero'
		when 'easysms' then 'EasySMS'
		when 'infobip' then 'Infobip'
		when '' then 'BuiltIn'
	 	else coalesce(JSONExtractString(settings, 'smsProvider'),'BuiltIn')
	  end as smsProvider
	, JSONExtractString(settings, 'smppHost') as smppHost
	, case
		when JSONExtractString(settings, 'smsProvider') = 'smsaero' then JSONExtractString(settings, 'smsAeroSender')
		when JSONExtractString(settings, 'smsProvider') = 'easysms' then JSONExtractString(settings, 'easySmsSender')
	 	else JSONExtractString(settings, 'smsSender')
	  end as smsSender
	, price_sms
	, price_smsProvider
	, case JSONExtractString(settings, 'flashCallProvider')
		when 'builtin' then 'BuiltIn'
		when 'smpp' then 'SMPP'
		when 'smsaero' then 'SmsAero'
		when 'easysms' then 'EasySMS'
		when 'infobip' then 'Infobip'
		else coalesce(JSONExtractString(settings, 'flashCallProvider'),'')
	  end as flashCallProvider
	, case JSONExtractString(settings, 'confirmationProvider')
		when 'sms' then 'SMS'
		when 'flash_call' then 'FlashCall'
		when '' then 'SMS'
		else coalesce(JSONExtractString(settings, 'confirmationProvider'),'SMS')
	  end as confirmationProvider
	, price_flashCallProvider
	, JSONExtractString(settings, 'emailFrom') as emailFrom
	, JSONExtractString(settings, 'emailFromName') as emailFromName
	, case JSONExtractString(settings, 'viberProvider')
		when 'builtin' then 'BuiltIn'
		when 'smpp' then 'SMPP'
		when 'smsaero' then 'SmsAero'
		when 'easysms' then 'EasySMS'
		when 'infobip' then 'Infobip'
		else coalesce(JSONExtractString(settings, 'viberProvider'),'')
	  end as viberProvider
	 , price_viber
from brand
where globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40');


--
-- Запуски / Команда
--
--Детальный отчёт по запускам для команды Запусков
--Тут есть сложноватая логика, когда мы считаем абонку запуска разную в зависимости от статуса бренда
--Типа пока он на интеграции берём прогнозную, пока пилот тоже, после пилота фактическую
drop table bi_starts_detailed;
create live view bi_starts_detailed with refresh 14400 as
with
pilot_end as
(select
	  bdf.brand_id as brand_id
	, bdf.dt as dt_pilot_end 
	, bdf.fee as fee_pilot_end
from bi_daily_fee bdf
left join bi_brand_pilot_dates b on b.brand_id = bdf.brand_id
where b.pilotTo is not null and bdf.dt = b.pilotTo + 1),
brand_tl as
(select
	  bs.brand_id
	, bs.dt
	, bs.status
	, bs.fee_start_date
	, pe.dt_pilot_end as fee_start_date_postpilot
	, min(bs.dt) over (partition by brand_id, fee_start_date) as dt_int_start
	, case when bs.dt = bs.fee_start_date then bs.fee_start else 0 end as fee_start
	, case when bs.dt = pe.dt_pilot_end then pe.fee_pilot_end else 0 end as fee_start_postpilot
	, sum(case when (bs.status = 0 or bs.status = 5) 
			and not ((month(bs.dt) = 12 and day(bs.dt) = 31) or (month(bs.dt) = 1 and day(bs.dt) <= 8)) then 1 else 0 end) 
		over (partition by bs.brand_id, bs.fee_start_date order by bs.dt rows between unbounded preceding and current row) as days_on_int 
	, case when (any(bs.status) over (partition by bs.brand_id order by bs.dt rows between 1 preceding and 1 preceding) < 3
			or any(bs.status) over (partition by bs.brand_id order by bs.dt rows between 1 preceding and 1 preceding) >= 5)
		and bs.status >= 3 and bs.status <> 5 and bs.status <> 6 then 1 else 0 end archive_flag
from bi_daily_starts bs
left join pilot_end pe on bs.brand_id = pe.brand_id),
brand_soft as
(select
	  brand_id
	, dt
	, arrayStringConcat(groupUniqArray(soft),', ') as soft
from bi_product_target_group 
group by 1,2)
select
	  btl.brand_id as brand_id
	, b.name as brand_name
	, bbm.accountManager as accountManager
	, bbm.salesManager as salesManager
	, bbm.projectManager as projectManager
	, btl.dt as dt
	, btl.status as status_int
	, case when btl.dt = max(btl.dt) over () then 1 else 0 end as last_dt
	, case
		when btl.status = 0 then 'На интеграции'
		when btl.status = 5 then 'Подготовка к запуску'
		when btl.status = 1 then case when bdc.brand_id is null then 'Активен' else 'Активен (пилот)' end
		when btl.status = 2 then 'Приостановлен'
		when btl.status = 3 then 'Архивный'
		when btl.status = 4 then 'Удалён'
		when btl.status = 6 then 'Возврат в продажи'
	  else 'Не известный' end as status
	, bs.soft as soft
	, btl.fee_start_date as start_dt
	, btl.dt_int_start as int_start_dt
	, max(case when archive_flag=1 then dt else null end) over (partition by btl.brand_id, btl.fee_start_date) as archive_dt
	, max(btl.fee_start) 
			over (partition by btl.brand_id, btl.fee_start_date) as fee_start_first
	, case
		when btl.dt < btl.fee_start_date then coalesce(toInt64(coalesce(bbc.fee_value_forecast,bbc.fee_value,tf.tariff_fee)),0)
		when bdc.brand_id is not null and btl.fee_start_date_postpilot is null then toInt64(coalesce(bbc.fee_value,tf.tariff_fee,0))
		else max(case when btl.fee_start_date_postpilot is null then btl.fee_start else btl.fee_start_postpilot end) 
			over (partition by btl.brand_id, btl.fee_start_date) end as fee_start	
	, btl.days_on_int as days_on_int
	, case
		when btl.dt < btl.fee_start_date then coalesce(bbc.clients_forecast, bbc.clients)
		when btl.dt < coalesce(btl.fee_start_date_postpilot, btl.fee_start_date) then bbc.clients
		else max(case when btl.dt=coalesce(btl.fee_start_date_postpilot, btl.fee_start_date) then bbc.clients else 0 end) 
			over (partition by btl.brand_id, btl.fee_start_date)
	  end as clients_on_start
	, toInt64(JSONExtractString(b.extraFields, 'expectedClientsCount')) as clients_forecast
	, case when btl.fee_start_date = btl.dt then 1 else 0 end as start_flag
	, btl.archive_flag as archive_flag
	, case 
		when btl.days_on_int <= 55 then 'x1.5' 
		when btl.days_on_int <= 65 then 'x1.0' 
		else 'x0.0' 
	  end as coeff
	, round(0.1 * case
		when btl.dt < btl.fee_start_date then coalesce(toInt64(coalesce(bbc.fee_value_forecast,bbc.fee_value,tf.tariff_fee)),0)
		when bdc.brand_id is not null and btl.fee_start_date_postpilot is null then toInt64(coalesce(bbc.fee_value,tf.tariff_fee,0))
		else max(case when btl.fee_start_date_postpilot is null then btl.fee_start else btl.fee_start_postpilot end) 
			over (partition by btl.brand_id, btl.fee_start_date) end +
	  case when btl.days_on_int > 65 then 0
	  else (66 - btl.days_on_int) * 0.1 * case
		when btl.dt < btl.fee_start_date then coalesce(toInt64(coalesce(bbc.fee_value_forecast,bbc.fee_value,tf.tariff_fee)),0)
		when bdc.brand_id is not null and btl.fee_start_date_postpilot is null then toInt64(coalesce(bbc.fee_value,tf.tariff_fee,0))
		else max(case when btl.fee_start_date_postpilot is null then btl.fee_start else btl.fee_start_postpilot end) 
			over (partition by btl.brand_id, btl.fee_start_date) end * 12 / 365
								  * case when btl.days_on_int <= 55 then 1.5 else 1.0 end
	  end) as bonus
	, case when crm.username is not null then false else true end as active_project_manager
from brand_tl btl
left join brand b on b.globalKey = btl.brand_id
left join bi_brand_managers bbm on bbm.brand_id = btl.brand_id and bbm.dt = btl.dt
left join brand_soft bs on bs.brand_id = btl.brand_id and bs.dt = btl.dt
left join bi_daily_brand_clients bbc on bbc.brand_id = btl.brand_id and bbc.dt = btl.dt
left join bi_daily_clients bdc on bdc.brand_id = btl.brand_id and bdc.dt = btl.dt and bdc.pilot = 1
left join (select distinct username from crm_operator where isActive = false or isDeleted = true) crm on crm.username = bbm.projectManager
left join (select brand_id, dt, sum(tariff_fee) as tariff_fee from bi_daily_tariff_module group by 1,2) tf 
	on tf.brand_id = btl.brand_id and tf.dt = btl.dt;

select * from bi_starts_detailed;

--CR по месяцам
drop table bi_monthly_CR;
create live view bi_monthly_CR with refresh 14400 as
with
cal as
(select
	distinct dt
from bi_daily_starts),
t0 as
(select
	  brand_id
	, date_trunc('month', dt) as dt_mon 
	, status
	, sum(fee_start) over (partition by brand_id, date_trunc('month', dt)) as start_sum
from bi_daily_starts),
t as
(select
	  dt_mon
	, count(distinct case when start_sum > 0 then brand_id else null end) /
	  nullif(count(distinct case when status = 0 or status = 5 then brand_id else null end),0) as CR
from t0
group by 1)
select 
	  cal.dt
	, t.CR 
from cal
left join t on date_trunc('month',cal.dt) = t.dt_mon;

select * from bi_monthly_CR;

--CR по новой логике общая
drop table bi_daily_CR;
create live view bi_daily_CR with refresh 14400 as
with t00 as
(select bdf.brand_id, bdf.dt, bdvs.v_start_days from bi_daily_fee bdf
left join bi_daily_v_start bdvs on bdvs.dt = bdf.dt and bdvs.brand_id = bdf.brand_id),
t0 as 
(select dt, median(v_start_days) as v_st from t00 group by 1),
cr_win as
(select
	  dt
	, toInt64((median(v_st) over (order by dt rows between 90 preceding and current row))) + 7 as cr_window
from t0),
started_brands as
(select 
	  b.dt as dt
	, case 
		when c.cr_window <=10 or c.cr_window is null then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 10 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=15 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 15 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=20 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 20 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=25 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 25 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=30 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 30 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=35 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 35 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=40 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 40 preceding and current row) > 0 
				then b.brand_id else null end
	    when c.cr_window <=45 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 45 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=50 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 50 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=55 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 55 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=60 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 60 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=65 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 65 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=70 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 70 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=75 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 75 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=80 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 80 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=85 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 85 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=90 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 90 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=95 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 95 preceding and current row) > 0 
				then b.brand_id else null end
		else
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 100 preceding and current row) > 0 
				then b.brand_id else null end 
		end as brand_id
from bi_starts_detailed b
left join cr_win c on c.dt = b.dt)
select
	  dt
	, case when (brand_int + brand_starts) > 0 then 1.0 * brand_starts / (brand_int + brand_starts) else null end as CR
	, brand_int
	, brand_starts
from
(select
	  dt
	, count(distinct brand_int) as brand_int
	, count(distinct brand_starts) as brand_starts
from 
(select
	  sd.dt as dt
	, case
	  when c.cr_window <=10 or c.cr_window is null then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=15 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=20 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=25 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=30 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=35 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=40 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=45 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=50 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=55 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=60 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=65 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=70 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=75 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=80 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=85 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=90 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=95 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  else
	  	  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  end as brand_int
	, sb.brand_id as brand_starts
from bi_starts_detailed sd
left join started_brands sb on sb.brand_id = sd.brand_id and sb.dt = sd.dt
left join cr_win c on c.dt = sd.dt) t group by 1) tt;

select * from bi_daily_CR;

--CR по новой логике по менеджерам
drop table bi_daily_CR_manager;
create live view bi_daily_CR_manager with refresh 14400 as
with t00 as
(select bdf.brand_id, bdf.dt, bdvs.v_start_days from bi_daily_fee bdf
left join bi_daily_v_start bdvs on bdvs.dt = bdf.dt and bdvs.brand_id = bdf.brand_id),
t0 as 
(select dt, median(v_start_days) as v_st from t00 group by 1),
cr_win as
(select
	  dt
	, toInt64((median(v_st) over (order by dt rows between 90 preceding and current row))) + 7 as cr_window
from t0),
started_brands as
(select 
	  b.dt as dt
	, case 
		when c.cr_window <=10 or c.cr_window is null then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 10 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=15 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 15 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=20 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 20 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=25 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 25 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=30 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 30 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=35 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 35 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=40 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 40 preceding and current row) > 0 
				then b.brand_id else null end
	    when c.cr_window <=45 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 45 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=50 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 50 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=55 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 55 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=60 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 60 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=65 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 65 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=70 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 70 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=75 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 75 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=80 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 80 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=85 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 85 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=90 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 90 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=95 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 95 preceding and current row) > 0 
				then b.brand_id else null end
		else
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 100 preceding and current row) > 0 
				then b.brand_id else null end 
		end as brand_id
from bi_starts_detailed b
left join cr_win c on c.dt = b.dt)
select
	  projectManager
	, dt
	, case when (brand_int + brand_starts) > 0 then 1.0 * brand_starts / (brand_int + brand_starts) else null end as CR
	, brand_int
	, brand_starts
from
(select
	  projectManager
	, dt
	, count(distinct brand_int) as brand_int
	, count(distinct brand_starts) as brand_starts
from 
(select
	  sd.projectManager as projectManager
	, sd.dt as dt
	, case
	  when c.cr_window <=10 or c.cr_window is null then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=15 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=20 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=25 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=30 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=35 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=40 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=45 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=50 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=55 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=60 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=65 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=70 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=75 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=80 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=85 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=90 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=95 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  else
	  	  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  end as brand_int
	, sb.brand_id as brand_starts
from bi_starts_detailed sd
left join started_brands sb on sb.brand_id = sd.brand_id and sb.dt = sd.dt
left join cr_win c on c.dt = sd.dt) t group by 1,2) tt
where projectManager is not null;

select * from bi_daily_CR_manager;

--Сводные данные по менеджерам с итогами
drop table bi_daily_CR_pivot;
create live view bi_daily_CR_pivot with refresh 14400 as
with total as
(select 
	  'Итого' as projectManager
	, dt
	, CR
	, brand_int
	, brand_starts
from bi_daily_CR)
select 
	  coalesce(t1.projectManager, t2.projectManager) as projectManager
	, coalesce(t1.dt, t2.dt) as dt
	, coalesce(t1.CR, t2.CR) as CR
	, coalesce(t1.brand_int, t2.brand_int) as brand_int
	, coalesce(t1.brand_starts, t2.brand_starts) as brand_starts
	from bi_daily_CR_manager t1
full join total t2 on false;

select * from bi_daily_CR_pivot;

--CR 180 дней

--CR по новой логике общая
drop table bi_daily_CR_180;
create live view bi_daily_CR_180 with refresh 14400 as
with t00 as
(select bdf.brand_id, bdf.dt, bdvs.v_start_days from bi_daily_fee bdf
left join bi_daily_v_start bdvs on bdvs.dt = bdf.dt and bdvs.brand_id = bdf.brand_id),
t0 as 
(select dt, median(v_start_days) as v_st from t00 group by 1),
cr_win as
(select
	  dt
	, toInt64((median(v_st) over (order by dt rows between 180 preceding and current row))) + 7 as cr_window
from t0),
started_brands as
(select 
	  b.dt as dt
	, case 
		when c.cr_window <=10 or c.cr_window is null then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 10 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=15 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 15 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=20 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 20 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=25 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 25 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=30 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 30 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=35 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 35 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=40 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 40 preceding and current row) > 0 
				then b.brand_id else null end
	    when c.cr_window <=45 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 45 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=50 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 50 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=55 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 55 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=60 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 60 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=65 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 65 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=70 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 70 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=75 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 75 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=80 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 80 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=85 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 85 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=90 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 90 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=95 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 95 preceding and current row) > 0 
				then b.brand_id else null end
		else
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 100 preceding and current row) > 0 
				then b.brand_id else null end 
		end as brand_id
from bi_starts_detailed b
left join cr_win c on c.dt = b.dt)
select
	  dt
	, case when (brand_int + brand_starts) > 0 then 1.0 * brand_starts / (brand_int + brand_starts) else null end as CR
	, brand_int
	, brand_starts
from
(select
	  dt
	, count(distinct brand_int) as brand_int
	, count(distinct brand_starts) as brand_starts
from 
(select
	  sd.dt as dt
	, case
	  when c.cr_window <=10 or c.cr_window is null then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=15 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=20 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=25 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=30 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=35 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=40 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=45 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=50 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=55 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=60 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=65 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=70 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=75 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=80 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=85 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=90 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=95 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  else
	  	  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) >= cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  end as brand_int
	, sb.brand_id as brand_starts
from bi_starts_detailed sd
left join started_brands sb on sb.brand_id = sd.brand_id and sb.dt = sd.dt
left join cr_win c on c.dt = sd.dt) t group by 1) tt;

select * from bi_daily_CR_180;

--CR по новой логике по менеджерам
drop table bi_daily_CR_manager_180;
create live view bi_daily_CR_manager_180 with refresh 14400 as
with t00 as
(select bdf.brand_id, bdf.dt, bdvs.v_start_days from bi_daily_fee bdf
left join bi_daily_v_start bdvs on bdvs.dt = bdf.dt and bdvs.brand_id = bdf.brand_id),
t0 as 
(select dt, median(v_start_days) as v_st from t00 group by 1),
cr_win as
(select
	  dt
	, toInt64((median(v_st) over (order by dt rows between 180 preceding and current row))) + 7 as cr_window
from t0),
started_brands as
(select 
	  b.dt as dt
	, case 
		when c.cr_window <=10 or c.cr_window is null then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 10 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=15 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 15 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=20 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 20 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=25 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 25 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=30 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 30 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=35 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 35 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=40 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 40 preceding and current row) > 0 
				then b.brand_id else null end
	    when c.cr_window <=45 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 45 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=50 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 50 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=55 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 55 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=60 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 60 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=65 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 65 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=70 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 70 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=75 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 75 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=80 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 80 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=85 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 85 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=90 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 90 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=95 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 95 preceding and current row) > 0 
				then b.brand_id else null end
		else
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 100 preceding and current row) > 0 
				then b.brand_id else null end 
		end as brand_id
from bi_starts_detailed b
left join cr_win c on c.dt = b.dt)
select
	  projectManager
	, dt
	, case when (brand_int + brand_starts) > 0 then 1.0 * brand_starts / (brand_int + brand_starts) else null end as CR
	, brand_int
	, brand_starts
from
(select
	  projectManager
	, dt
	, count(distinct brand_int) as brand_int
	, count(distinct brand_starts) as brand_starts
from 
(select
	  sd.projectManager as projectManager
	, sd.dt as dt
	, case
	  when c.cr_window <=10 or c.cr_window is null then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=15 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=20 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=25 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=30 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=35 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=40 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=45 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=50 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=55 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=60 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=65 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=70 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=75 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=80 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=85 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=90 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=95 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  else
	  	  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  end as brand_int
	, sb.brand_id as brand_starts
from bi_starts_detailed sd
left join started_brands sb on sb.brand_id = sd.brand_id and sb.dt = sd.dt
left join cr_win c on c.dt = sd.dt) t group by 1,2) tt
where projectManager is not null;

select * from bi_daily_CR_manager_180;

--Сводные данные по менеджерам с итогами
drop table bi_daily_CR_pivot_180;
create live view bi_daily_CR_pivot_180 with refresh 14400 as
with total as
(select 
	  'Итого' as projectManager
	, dt
	, CR
	, brand_int
	, brand_starts
from bi_daily_CR_180)
select 
	  coalesce(t1.projectManager, t2.projectManager) as projectManager
	, coalesce(t1.dt, t2.dt) as dt
	, coalesce(t1.CR, t2.CR) as CR
	, coalesce(t1.brand_int, t2.brand_int) as brand_int
	, coalesce(t1.brand_starts, t2.brand_starts) as brand_starts
	from bi_daily_CR_manager_180 t1
full join total t2 on false;

select * from bi_daily_CR_pivot_180;

-----

--Добавление метрики CR для отчёта
drop table bi_starts_detailed_w_CR;
create live view bi_starts_detailed_w_CR with refresh 14400 as
select
	  sd.*
	, bdcm.CR as CR_via_manager
from bi_starts_detailed sd
left join bi_daily_CR_manager bdcm on bdcm.dt = sd.dt and bdcm.projectManager = sd.projectManager

select * from bi_starts_detailed_w_CR;


--
-- Отчет по рассылкам через клиентов
--
--Его делали для детального анализа рассылок, думаю пока его тоже не буду описывать, в целом он схож с верхнеуровневым отчётом
--Витрина собирается через airflow
--create live view bi_client_sendings with refresh 14400 as
with b_data_add_raw as
(select
	  distinct
	  brand_id
	, rev_type
	, industry
from bi_product_target_group
order by 1,3),
b_data_add as
(select
	  brand_id
	, coalesce(rev_type, 'Нет данных') as rev_type
	, case when arrayStringConcat(groupArray(industry),' | ') = '' then 'Нет данных'
		else arrayStringConcat(groupArray(industry),' | ') end as industry
from b_data_add_raw
group by 1,2),
mb as
(select
	  case 
		when m.type = 0 then 'Автоматические рассылки'
		when m.type = 1 then 'Ручные рассылки'
	  end as sending_type
	, m.globalKey
	, m.id as mailingBrandId
	, case
		when m.type = 1 and m.triggerType in (0) then 'Без триггера'
		when m.triggerType in (8,9,10,11) then 'Брошенные корзины'
		when m.triggerType in (0) then 'Переход в сегмент'
		when m.triggerType in (1) then 'Выход из сегмента'
		when m.triggerType in (2) then 'Активация бонуса'
		when m.triggerType in (3) then 'Возврат покупки'
		when m.triggerType in (4) then 'День Рождения'
		when m.triggerType in (5) then 'Сгорание бонуса'
		when m.triggerType in (6) then 'Покупка'
		when m.triggerType in (7) then 'День Рождения ребёнка'
		when m.triggerType in (8) then 'Активация бонуса'
		else 'Без триггера'
	  end as trigger_type
	, m.name as name
	, trim(concat(
	  case when m.channels ilike '%"sms": true%' then 'SMS ' else '' end
	, case when m.channels ilike '%"email": true%' then 'E-Mail ' else '' end
	, case when m.channels ilike '%"push": true%' then 'Push ' else '' end
	, case when m.channels ilike '%"viber": true%' then 'Viber ' else '' end)) as channel
from mailing_brand m
where m.isDeleted = false),
purch as 
(select
	  globalKey
	, mailingBrandId
	, clientId
	, sum(case when coalesce(paidAmount,0)>0 then 1 else 0 end) as orders
	, sum(coalesce(paidAmount,0)) as revenue
	, sum(coalesce(offerDiscount,0) + coalesce(promocodeDiscount,0) + coalesce(bonusesDiscount,0)) as lost_sum
from purchase
where mailingBrandId is not null
group by 1,2,3),
lost_m as
(select
	  globalKey
	, mailingBrandId
	, sum(coalesce(statAmount,0)) as lost_maxma
from expense
where mailingBrandId is not null and operation>0
group by 1,2),
agg as
(select
	  m.globalKey as brand_id
	, m.mailingBrandId as mailingBrandId
	, mb.sending_type as sending_type
	, mb.trigger_type as trigger_type
	, mb.name as name
	, mb.channel as channel
	, toDayOfWeek(m.createdAt + toIntervalHour(coalesce(c.tzOffsetHours,0))) as sending_dow
	, toHour(m.createdAt + toIntervalHour(coalesce(c.tzOffsetHours,0))) as sending_hour
	, toDate(m.createdAt + toIntervalHour(coalesce(c.tzOffsetHours,0))) as sending_dt
	, count(m.clientId) as base_qty
	, sum(case when m.delivered then 1 else 0 end) as deliver
	, sum(case when m.openedAt is not null then 1 else 0 end) as open
	, sum(case when m.unsubscribed then 1 else 0 end) as unsubscribe
	, sum(coalesce(p.orders,0)) as orders
	, sum(coalesce(p.revenue,0)) as revenue
	, sum(coalesce(p.lost_sum,0)) as lost_sum
from mailing_sending m
join mb on mb.globalKey = m.globalKey and mb.mailingBrandId = m.mailingBrandId
left join client c on c.globalKey = m.globalKey and c.id = m.clientId
left join purch p on p.globalKey = m.globalKey and p.mailingBrandId = m.mailingBrandId and p.clientId = m.clientId
where m.createdAt is not null 
--	and m.createdAt>= now() - toIntervalDay(90)
group by 1,2,3,4,5,6,7,8,9)
select
	  a.brand_id as brand_id
	, b.name as brand_name
	, a.sending_type as sending_type
	, a.trigger_type as trigger_type
	, a.name as sending_name
	, a.sending_dow as sending_dow
	, a.sending_hour as sending_hour
	, a.base_qty as base_qty
	, a.deliver as deliver
	, a.open as open
	, a.unsubscribe as unsubscribe
	, a.orders as orders
	, a.revenue as revenue
	, a.lost_sum as lost_sum
	, case when sum(a.base_qty) over (partition by a.mailingBrandId) = 0
		then coalesce(lm.lost_maxma,0) / count(*) over (partition by a.mailingBrandId)
		else a.base_qty * coalesce(lm.lost_maxma,0) / sum(a.base_qty) over (partition by a.mailingBrandId)
	  end as lost_maxma
	, a.sending_dt as sending_dt
	, ceiling((a.sending_dt - date_trunc('month', a.sending_dt))/7) as num_day_in_month
	, a.channel as channel
	, bd.rev_type as rev_type
	, bd.industry as industry
from agg a
left join lost_m lm on lm.globalKey = a.brand_id and lm.mailingBrandId = a.mailingBrandId
left join brand b on b.globalKey = a.brand_id
left join b_data_add bd on bd.brand_id = a.brand_id
order by 1,4,5,6;

select * from bi_client_sendings;


----
--Ведение клиентов - Причины отключения
----
--Анализ брендов по причинам отключения
drop table bi_client_lost_reason;
create live view bi_client_lost_reason with refresh 14400 as
with arch as
(select
	  globalKey as brand_id
	, name as brand_name
    , createdAt as int_dt_base
    , discontinuedAt as lost_dt_base
    , status
    , JSONExtractString(settings, 'archiveComment') as archiveComment
    , JSONExtractString(settings, 'alternative') as alternative
    , JSONExtractString(settings, 'alternativeCompany') as alternativeCompany
    , JSONExtractString(settings, 'possibleComeBack') as possibleComeBack
    , JSONExtractString(settings, 'possibleComeBackDate') as possibleComeBackDate
    , JSONExtractString(settings, 'archiveInitiator') as archiveInitiator
from brand
where status in (2,3,4)
and globalKey not in ('587aa3d2-269e-4630-a266-bbbcc784470f','e695fef3-d57e-42f2-a2e3-b3b085a21a93','44759604-3723-4512-a447-2d7184172a40')),
arch_w_dt as 
(select
	  b.brand_id as brand_id
	, a.brand_name as brand_name
	, a.archiveComment as archiveComment
	, a.alternative as alternative
	, a.alternativeCompany as alternativeCompany
	, a.possibleComeBack as possibleComeBack
	, a.possibleComeBackDate as possibleComeBackDate
	, a.archiveInitiator as archiveInitiator
    , a.int_dt_base as int_dt_base
    , a.lost_dt_base as lost_dt_base
    , a.status as status
	, max(case when b.fee > 0 then b.dt end) as last_fee_dt
	, min(case when b.status = 3 then b.dt end) as archive_dt
from bi_daily_fee b
join arch a using(brand_id)
group by 1,2,3,4,5,6,7,8,9,10,11),
brand_data as
(select
	  brand_id
	, arrayStringConcat(groupUniqArray(industry),', ') as industry
	, arrayStringConcat(groupUniqArray(soft),', ') as soft
	, max(shops_qty) as shops_qty
from bi_product_target_group
group by 1),
t as
(select
	  b.brand_id as brand_id
	, a.brand_name as brand_name
	, b.archiveReason as archiveReason
	, a.archiveComment as archiveComment
	, a.alternative as alternative
	, a.alternativeCompany as alternativeCompany
	, a.possibleComeBack as possibleComeBack
	, a.possibleComeBackDate as possibleComeBackDate
	, a.archiveInitiator as archiveInitiator
	, a.status as status
	, max(case when b.dt = a.last_fee_dt then b.monthly_fee end) as monthly_fee
	, toDate(min(a.int_dt_base)) as int_date
	, max(a.last_fee_dt) as last_fee_dt
    , coalesce(min(a.lost_dt_base),date_add(day,1,max(a.last_fee_dt)),min(a.archive_dt)) as lost_dt
	, sum(case when (b.integration = 1 or b.integration_active = 1)
			and not ((month(b.dt) = 12 and day(b.dt) = 31) or (month(b.dt) = 1 and day(b.dt) <= 8)) then 1 else 0 end) as days_on_int
	, max(case when b.dt = a.last_fee_dt then b.LT_on_date end) as LT
	, max(case when b.dt = a.last_fee_dt then b.LTV_on_date end) as LTV
from bi_daily_brand_data b 
join arch_w_dt a using(brand_id)
group by 1,2,3,4,5,6,7,8,9,10)
select
	  t.brand_id as brand_id
	, t.brand_name as brand_name
	, t.archiveReason as archiveReason
	, t.archiveComment as archiveComment
	, t.alternative as alternative
	, t.alternativeCompany as alternativeCompany
	, t.possibleComeBack as possibleComeBack
	, t.possibleComeBackDate as possibleComeBackDate
	, t.archiveInitiator as archiveInitiator
	, t.monthly_fee as monthly_fee
	, t.int_date as int_date
	, t.last_fee_dt as last_fee_dt
	, t.lost_dt as lost_dt 
	, t.days_on_int as days_on_int
	, case
		when t.status = 2 then 'Приостановлен'
		when t.status = 3 then 'Архивный'
		when t.status = 4 then 'Удалён'
	  else 'Не известный' end as status
	, t.LT as LT
	, t.LTV as LTV
	, coalesce(bbm.accountManager,'Не назначен') as accountManager
	, coalesce(bbm.salesManager ,'Не назначен') as salesManager
	, coalesce(bbm.projectManager,'Не назначен') as projectManager
	, coalesce(dbc.clients,0) as clients_qty_before_lost
	, bd.industry as industry
	, bd.soft as soft
	, bd.shops_qty as shops_qty
from t
left join bi_brand_managers bbm on bbm.brand_id = t.brand_id and bbm.dt = t.lost_dt
left join bi_daily_brand_clients dbc on dbc.brand_id = t.brand_id and dbc.dt = t.lost_dt
left join brand_data bd on bd.brand_id = t.brand_id;

select * from bi_client_lost_reason;

----
--Продажи - Реферальный отчёт
----
--Отчёт для расчёта выплат рефералам. Есть реферальная программа, где компании могут посоветовать или пригласить в проект другую компанию и получают бонус как % от абонки "друга" 

--Таблица выплат
drop table bi_referer_bonuses;
create live view bi_referer_bonuses with refresh 14400 as
with st as
(select
	  brand_id
	, min(fee_start_date) as start_dt
from bi_daily_starts
group by 1),
bd as
(select
	  globalKey as brand_id
	, name as partner_name
	, toDate(createdAt) as int_date
	, case
		when status = 0 then 'На интеграции'
		when status = 5 then 'Подготовка к запуску'
		when status = 1 then 'Активен'
		when status = 2 then 'Приостановлен'
		when status = 3 then 'Архивный'
		when status = 4 then 'Удалён'
		when status = 6 then 'Возврат в продажи'
	  else 'Не известный' end as status
	, JSONExtractString(settings, 'leadSource') as referer
from brand
where JSONExtractString(settings, 'leadType') = 'partner'), --определяем тип привлечения бренда, в данном случае смотрим реферальные = partner
total as
(select
	  bd.referer as referer
	, bd.partner_name as partner_name
	, bd.brand_id as brand_id
	, bd.status as status
	, bd.int_date as int_date
	, st.start_dt as start_dt
	, date_trunc('month',b.dt) as dt_mon
	, case when b.dt < st.start_dt then null
		else 1 + date_diff('month',date_trunc('month',st.start_dt),date_trunc('month',b.dt)) end as mon_num
	, sum(b.daily_fee) as fee
from bi_daily_fee b
join bd on bd.brand_id = b.brand_id
left join st on st.brand_id = b.brand_id
where b.dt >= st.start_dt
group by 1,2,3,4,5,6,7,8)
select
	  distinct
	  t.referer
	, rs.inn
	, rs.email
	, t.partner_name
	, t.brand_id
	, t.status
	, int_date
	, start_dt
	, dt_mon
	, case when dt_mon = max(dt_mon) over () then true else false end as last_mon
	, case when dt_mon = date_trunc('month',max(dt_mon) over() - 1) then true else false end prelast_mon
	, case when date_trunc('quarter',dt_mon) = date_trunc('quarter',max(dt_mon) over ()) then true else false end as curr_q
	, case when year(dt_mon) = year(max(dt_mon) over ()) then true else false end as curr_year
	, t.mon_num
	, t.fee
	, max(case when rs.monFrom <= t.mon_num and rs.monTo >= t.mon_num then rs.tax else null end) over (partition by t.brand_id, dt_mon) as tax
	, max(case when rs.monFrom <= t.mon_num and rs.monTo >= t.mon_num then rs.bonus else null end) over (partition by t.brand_id, dt_mon) as bonus
	, max(case when rs.monFrom <= t.mon_num and rs.monTo >= t.mon_num 
		then (t.fee - t.fee * rs.tax) * rs.bonus else null end) over (partition by t.brand_id, dt_mon) as referer_bonus
from total t
left join bi_referer_settings rs on rs.name = t.referer; --таблица с условиями выплат для рефери

select * from bi_referer_bonuses;


----
--Продажи - Выплаты сотрудникам
--Расчёт вылпат менеджерам продаж

drop table bi_sales_manager_bonuses;
create live view bi_sales_manager_bonuses with refresh 14400 as
with st as
(select
	  brand_id
	, min(fee_start_date) as start_dt
from bi_daily_starts
group by 1),
bbm as
(select
	  distinct
	  brand_id
	, first_value(salesManager) over (partition by brand_id order by case when salesManager = 'Не назначен' then 1 else 0 end, dt) as salesManager
from bi_brand_managers),
bd as
(select
	  b.globalKey as brand_id
	, b.name as client
	, toDate(b.createdAt) as int_date
	, bp.pilotFrom as pilot_date
	, case
		when b.status = 0 then 'На интеграции'
		when b.status = 5 then 'Подготовка к запуску'
		when b.status = 1 then 'Активен'
		when b.status = 2 then 'Приостановлен'
		when b.status = 3 then 'Архивный'
		when b.status = 4 then 'Удалён'
		when b.status = 6 then 'Возврат в продажи'
	  else 'Не известный' end as status_current
	, case 
		when JSONExtractString(b.settings, 'leadType') = 'traffic' then 'Входящий'
		when JSONExtractString(b.settings, 'leadType') = 'sales' then 'Активная продажа'
		when JSONExtractString(b.settings, 'leadType') = 'partner' then 'По рекомендации'
		when JSONExtractString(b.settings, 'leadType') = 'tm' then 'ТМ'
	  else 'Не определён' end as lead_type
	, JSONExtractString(b.settings, 'leadSource') as referer
from brand b
left join bi_brand_pilot_dates bp on bp.brand_id = b.globalKey),
total as
(select
	  bbm.salesManager as salesManager
	, bd.client as client
	, bd.brand_id as brand_id
	, bd.lead_type as lead_type
	, bd.referer as referer
	, case
		when b.status = 0 then 'На интеграции'
		when b.status = 5 then 'Подготовка к запуску'
		when b.status = 1 then 'Активен'
		when b.status = 2 then 'Приостановлен'
		when b.status = 3 then 'Архивный'
		when b.status = 4 then 'Удалён'
		when b.status = 6 then 'Возврат в продажи'
	  else 'Не известный' end as status
	, bd.status_current as status_current
	, bd.int_date as int_date
	, st.start_dt as start_dt
	, b.dt as dt
	, case when b.pilot_date is not null and b.pilot_date > min(case when b.daily_fee > 0 then b.dt else null end) over (partition by b.brand_id)
		then b.pilot_date else
		min(case when b.daily_fee > 0 then b.dt else null end) over (partition by b.brand_id) end as start_pay --дата начала расчёта выплат
	, date_add(day, bs.smDays - 1, min(case when b.daily_fee > 0 then b.dt else null end) over (partition by b.brand_id)) as end_pay --дата окончания расчёта выплат
	, coalesce(bs.smBonus,0) as p_sm --% менеджеру продаж
	, coalesce(bs.ropBonus,0) as p_sl --% лиду менеджеров продаж
	, coalesce(bs.tmBonus,0) as p_tm --% операторам телемаркетинга
	, coalesce(bs.roptmBonus,0) as p_tml --% лиду операторов телемаркетинга
	, b.daily_fee as fee
from bi_daily_fee b
join bd on bd.brand_id = b.brand_id
left join st on st.brand_id = b.brand_id
left join bbm on bbm.brand_id = b.brand_id
left join bi_sales_bonus_settings bs on bs.leadType = bd.lead_type) --таблица с правилами выплат для разных категорий сотрудников
select 
	  t.salesManager as salesManager
	, t.client as client
	, t.brand_id as brand_id
	, t.lead_type as lead_type
	, t.referer as referer
	, t.status as status
	, t.status_current as status_current
	, t.int_date as int_date
	, t.start_dt as start_dt
	, t.dt as dt
	, t.start_pay as start_pay
	, t.end_pay as end_pay
	, case when t.start_dt < '2023-12-01' then 0 else t.p_tm end as p_tm --Телемаркетингу начали платить с декабря 23 года
	, case when t.start_dt < '2023-12-01' then 0 else t.p_tml end as p_tml
	, t.p_sm as p_sm
	, t.p_sl as p_sl
	, t.fee as fee
	, rs.mon_num as ref_mon_num
	, rs.tax as ref_tax
	, rs.bonus as ref_bonus
	, (t.fee - t.fee * rs.tax) * rs.bonus as referer_bonus --в базе для расчёта % учитываем сумму выплат реферерам (уменьшаем выручку на эту сумму ниже)
	, case when t.dt >= t.start_pay and t.dt <= t.end_pay and t.start_dt < '2023-12-01' then 
		toDecimal128(t.fee * t.p_tm,8)
	  else 0 end as tm_bonus
	, case when t.dt >= t.start_pay and t.dt <= t.end_pay and t.start_dt < '2023-12-01' then 
		toDecimal128(t.fee * t.p_tml,8)
	  else 0 end as tml_bonus
	, case when t.dt >= t.start_pay and t.dt <= t.end_pay then 
		case when t.lead_type = 'По рекомендации' then toDecimal128((t.fee - (t.fee - t.fee * rs.tax) * rs.bonus) * t.p_sm,8)
		else toDecimal128(t.fee * t.p_sm,8) end
	  else 0 end as manager_bonus
	, case when t.dt >= t.start_pay and t.dt <= t.end_pay then 
		case when t.lead_type = 'По рекомендации' then toDecimal128((t.fee - (t.fee - t.fee * rs.tax) * rs.bonus) * t.p_sl,8)
		else toDecimal128(t.fee * t.p_sl,8) end
	  else 0 end as leader_bonus
from total t
left join bi_referer_bonuses rs on rs.brand_id = t.brand_id and rs.dt_mon = date_trunc('month',t.dt);

select * from bi_sales_manager_bonuses;


--------
-- Продукт / Модули
--------
--Отчёт по аналитике продуктовой платформы.

-----
--Финальный вариант отчёта по модулям
-----

create materialized view bi_product_moduls_revenue_lost_maxma engine = MergeTree() order by dt populate as
with rfm_flag as 
(select 
	  id
	, case when JSONExtractString(JSONExtractString(recipients, 'filters'),'conditions') ilike '%rfmsegments%' then 1 else 0 end as rfm_flag
from mailing_brand),
wallet_mb_list as
(select 
	distinct mailingBrandId
from mailing_sending ms
join (select distinct clientId from wallet_card) c using(clientId)),
t as
(select
	  ex.globalKey as brand_id
	, date(ex.billedAt  + 3*3600) as dt
	, coalesce(case when mb.type = 0 and mb.triggerType not in (8,9,10,11) then ex.statAmount else 0 end,0) as sendings_auto_lost_maxma
	, coalesce(case when mb.type = 1 and mb.triggerType not in (8,9,10,11) then ex.statAmount else 0 end,0) as sendings_hand_lost_maxma
	, coalesce(case when mb.triggerType in (8,9,10,11) then ex.statAmount else 0 end,0) as sendings_adcart_lost_maxma
	, coalesce(case when mb.type = 0 and mb.channels ilike '%"sms": true%' then ex.statAmount else 0 end,0) as sendings_auto_sms_lost_maxma
	, coalesce(case when mb.type = 1 and mb.channels ilike '%"sms": true%' then ex.statAmount else 0 end,0) as sendings_hand_sms_lost_maxma
	, coalesce(case when mb.type = 0 and mb.channels ilike '%"push": true%' then ex.statAmount else 0 end,0) as sendings_auto_push_lost_maxma
	, coalesce(case when mb.type = 1 and mb.channels ilike '%"push": true%' then ex.statAmount else 0 end,0) as sendings_hand_push_lost_maxma
	, coalesce(case when mb.type = 0 and mb.triggerType not in (8,9,10,11) and mb.channels ilike '%"email": true%' then ex.statAmount else 0 end,0) as sendings_auto_email_lost_maxma
	, coalesce(case when mb.type = 1 and mb.triggerType not in (8,9,10,11) and mb.channels ilike '%"email": true%' then ex.statAmount else 0 end,0) as sendings_hand_email_lost_maxma
	, coalesce(case when mb.type = 0 and mb.channels ilike '%"viber": true%' then ex.statAmount else 0 end,0) as sendings_auto_viber_lost_maxma
	, coalesce(case when mb.type = 1 and mb.channels ilike '%"viber": true%' then ex.statAmount else 0 end,0) as sendings_hand_viber_lost_maxma
	, coalesce(case when r.rfm_flag = 1 then ex.statAmount else 0 end,0) as rfm_lost_maxma
	, coalesce(case when mb.channels ilike '%"push": true%' and w.mailingBrandId is not null then ex.statAmount else 0 end,0) as wallet_lost_maxma
from expense ex
left join mailing_brand mb on mb.id = ex.mailingBrandId and mb.globalKey = ex.globalKey
left join rfm_flag r on r.id = mb.id
left join wallet_mb_list w on w.mailingBrandId = mb.id
where ex.mailingBrandId is not null and ex.operation > 0 and date(ex.billedAt  + 3*3600) >= '2023-04-01')
select
	  brand_id
	, dt
	, sum(sendings_auto_lost_maxma) as sendings_auto_lost_maxma
	, sum(sendings_hand_lost_maxma) as sendings_hand_lost_maxma
	, sum(sendings_adcart_lost_maxma) as sendings_adcart_lost_maxma
	, sum(sendings_auto_sms_lost_maxma) as sendings_auto_sms_lost_maxma
	, sum(sendings_hand_sms_lost_maxma) as sendings_hand_sms_lost_maxma
	, sum(sendings_auto_push_lost_maxma) as sendings_auto_push_lost_maxma
	, sum(sendings_hand_push_lost_maxma) as sendings_hand_push_lost_maxma
	, sum(sendings_auto_email_lost_maxma) as sendings_auto_email_lost_maxma
	, sum(sendings_hand_email_lost_maxma) as sendings_hand_email_lost_maxma
	, sum(sendings_auto_viber_lost_maxma) as sendings_auto_viber_lost_maxma
	, sum(sendings_hand_viber_lost_maxma) as sendings_hand_viber_lost_maxma
	, sum(rfm_lost_maxma) as rfm_lost_maxma
	, sum(wallet_lost_maxma) as wallet_lost_maxma
from t
group by 1,2;

create materialized view bi_product_moduls_revenue engine = MergeTree() order by dt populate as
with rfm_flag as 
(select 
	  id
	, case when JSONExtractString(JSONExtractString(recipients, 'filters'),'conditions') ilike '%rfmsegments%' then 1 else 0 end as rfm_flag
from mailing_brand),
wallet_clients as
(select 
	distinct clientId 
from wallet_card),
lead_form_clients as
(select
	distinct c.id
from client c
join shop s on s.id = c.issuerShopId
where s.code = 'webForm'),
t as
(select
	  p.globalKey as brand_id
	, date(p.createdAt  + 3*3600) as dt
	, case when mb.type = 0 and mb.triggerType not in (8,9,10,11) then 1 else 0 end as sendings_auto
	, case when mb.type = 1 and mb.triggerType not in (8,9,10,11) then 1 else 0 end as sendings_hand
	, case when mb.triggerType in (8,9,10,11) then 1 else 0 end as sendings_adcart
	, case when mb.type = 0 and mb.channels ilike '%"sms": true%' then 1 else 0 end as sendings_auto_sms
	, case when mb.type = 1 and mb.channels ilike '%"sms": true%' then 1 else 0 end as sendings_hand_sms
	, case when mb.type = 0 and mb.channels ilike '%"push": true%' then 1 else 0 end as sendings_auto_push
	, case when mb.type = 1 and mb.channels ilike '%"push": true%' then 1 else 0 end as sendings_hand_push
	, case when mb.type = 0 and mb.triggerType not in (8,9,10,11) and mb.channels ilike '%"email": true%' then 1 else 0 end as sendings_auto_email
	, case when mb.type = 1 and mb.triggerType not in (8,9,10,11) and mb.channels ilike '%"email": true%' then 1 else 0 end as sendings_hand_email
	, case when mb.type = 0 and mb.channels ilike '%"viber": true%' then 1 else 0 end as sendings_auto_viber
	, case when mb.type = 1 and mb.channels ilike '%"viber": true%' then 1 else 0 end as sendings_hand_viber
	, case when po.offerId is not null then 1 else 0 end as offer
	, case when pc.id is not null and pc.codeType in (0,1) then 1 else 0 end as promocode
	, case when pc.id is not null and pc.codeType = 2 then 1 else 0 end as promo_friend
	, case when gc.id is not null then 1 else 0 end as gift_card
	, case when p.mailingBrandId is null and po.offerId is null and pc.id is null and gc.id is null then 1 else 0 end as base
	, case when r.rfm_flag = 1 then 1 else 0 end as rfm
	, case when c.id is not null then 1 else 0 end as lead_form
	, case when w.clientId is not null then 1 else 0 end as wallet
	, coalesce(p.paidAmount,0) as revenue
	, coalesce(p.offerDiscount,0) + coalesce(p.promocodeDiscount,0) + coalesce(p.bonusesDiscount,0) as lost_sum
from purchase p
left join mailing_brand mb on mb.id = p.mailingBrandId and mb.globalKey = p.globalKey
left join rfm_flag r on r.id = mb.id
left join purchase_offer po on po.purchaseId = p.id and po.globalKey = p.globalKey
left join promocode pc on pc.id = p.promocodeId and pc.globalKey = p.globalKey
left join gift_card_applied gc on gc.purchaseId = p.id and gc.globalKey = p.globalKey
left join lead_form_clients c on c.id = p.clientId
left join wallet_clients w on w.clientId = p.clientId
where date(p.createdAt  + 3*3600) >= '2023-04-01')
select
	  brand_id
	, dt
	, sum(case when sendings_auto = 1 then revenue else 0 end) as revenue_sendings_auto
	, sum(case when sendings_auto = 1 then lost_sum else 0 end) as lost_sum_sendings_auto
	, sum(case when sendings_hand = 1 then revenue else 0 end) as revenue_sendings_hand
	, sum(case when sendings_hand = 1 then lost_sum else 0 end) as lost_sum_sendings_hand
	, sum(case when sendings_adcart = 1 then revenue else 0 end) as revenue_sendings_adcart
	, sum(case when sendings_adcart = 1 then lost_sum else 0 end) as lost_sum_sendings_adcart
	, sum(case when sendings_auto_sms = 1 then revenue else 0 end) as revenue_sendings_auto_sms
	, sum(case when sendings_auto_sms = 1 then lost_sum else 0 end) as lost_sum_sendings_auto_sms
	, sum(case when sendings_hand_sms = 1 then revenue else 0 end) as revenue_sendings_hand_sms
	, sum(case when sendings_hand_sms = 1 then lost_sum else 0 end) as lost_sum_sendings_hand_sms
	, sum(case when sendings_auto_push = 1 then revenue else 0 end) as revenue_sendings_auto_push
	, sum(case when sendings_auto_push = 1 then lost_sum else 0 end) as lost_sum_sendings_auto_push
	, sum(case when sendings_hand_push = 1 then revenue else 0 end) as revenue_sendings_hand_push
	, sum(case when sendings_hand_push = 1 then lost_sum else 0 end) as lost_sum_sendings_hand_push
	, sum(case when sendings_auto_email = 1 then revenue else 0 end) as revenue_sendings_auto_email
	, sum(case when sendings_auto_email = 1 then lost_sum else 0 end) as lost_sum_sendings_auto_email
	, sum(case when sendings_hand_email = 1 then revenue else 0 end) as revenue_sendings_hand_email
	, sum(case when sendings_hand_email = 1 then lost_sum else 0 end) as lost_sum_sendings_hand_email
	, sum(case when sendings_auto_viber = 1 then revenue else 0 end) as revenue_sendings_auto_viber
	, sum(case when sendings_auto_viber = 1 then lost_sum else 0 end) as lost_sum_sendings_auto_viber
	, sum(case when sendings_hand_viber = 1 then revenue else 0 end) as revenue_sendings_hand_viber
	, sum(case when sendings_hand_viber = 1 then lost_sum else 0 end) as lost_sum_sendings_hand_viber
	, sum(case when offer = 1 then revenue else 0 end) as revenue_offer
	, sum(case when offer = 1 then lost_sum else 0 end) as lost_sum_offer
	, sum(case when promocode = 1 then revenue else 0 end) as revenue_promocode
	, sum(case when promocode = 1 then lost_sum else 0 end) as lost_sum_promocode
	, sum(case when promo_friend = 1 then revenue else 0 end) as revenue_promo_friend
	, sum(case when promo_friend = 1 then lost_sum else 0 end) as lost_sum_promo_friend
	, sum(case when gift_card = 1 then revenue else 0 end) as revenue_gift_card
	, sum(case when gift_card = 1 then lost_sum else 0 end) as lost_sum_gift_card
	, sum(case when base = 1 then revenue else 0 end) as revenue_base
	, sum(case when base = 1 then lost_sum else 0 end) as lost_sum_base
	, sum(case when rfm = 1 then revenue else 0 end) as revenue_rfm
	, sum(case when rfm = 1 then lost_sum else 0 end) as lost_sum_rfm
	, sum(case when lead_form = 1 then revenue else 0 end) as revenue_lead_form
	, sum(case when lead_form = 1 then lost_sum else 0 end) as lost_sum_lead_form
	, sum(case when wallet = 1 then revenue else 0 end) as revenue_wallet
	, sum(case when wallet = 1 then lost_sum else 0 end) as lost_sum_wallet
from t
group by 1,2;

select * from bi_product_moduls_revenue_lost_maxma;

select * from bi_product_moduls_revenue;


create materialized view bi_product_moduls engine = MergeTree() order by dt populate as 
with ind as
(select
	  globalKey as brand_id
	, case when arrayStringConcat(groupArray(replaceAll(ind,'"','')),' | ') = '' then 'Нет данных'
		else arrayStringConcat(groupArray(replaceAll(ind,'"','')),' | ') end as industry
from brand
	array join JSONExtractArrayRaw(coalesce(JSONExtractString(extraFields, 'industry'), '[]')) as ind
	group by 1),
soft as
(select
	  globalKey as brand_id
	, case when arrayStringConcat(groupArray(replaceAll(possoft,'"','')),' | ') = '' then 'Нет данных'
		else arrayStringConcat(groupArray(replaceAll(possoft,'"','')),' | ') end as soft
from brand
	array join JSONExtractArrayRaw(coalesce(JSONExtractString(extraFields, 'posSoftware'), '[]')) as possoft
	group by 1),
wallet_mb_list as
(select 
	distinct mailingBrandId
from mailing_sending ms
join (select distinct clientId from wallet_card) c using(clientId)),
rfm as
(select
	  globalKey as brand_id
	, 'RFM' as sub_module_name
	, case when JSONExtractString(features, 'rfm') = 'true' then 1 else 0 end as activation
from brand),
email as
(select
	  globalKey as brand_id
	, 'Email' as low_module_name
	, case when JSONExtractString(features, 'emailEditor') = 'true' then 1 else 0 end as activation
from brand),
viber as
(select
	  globalKey as brand_id
	, 'Viber' as low_module_name
	, case when JSONExtractString(settings, 'viberEnabled') = 'true' then 1 else 0 end as activation
from brand),
abadone_cart as
(select
	  b.globalKey as brand_id
	, 'Брошенные корзины' as sub_module_name
	, case when mb.brand_id is not null then 1 else 0 end as activation
from brand b
left join
(select
	distinct globalKey as brand_id
from mailing_brand mb
where not isDeleted and triggerType in (8,9,10,11)) mb on mb.brand_id = b.globalKey),
offers as
(select
	  globalKey as brand_id
	, 'Акции' as sub_module_name
	, case when JSONExtractString(features, 'discountOffer') = 'true' then 1 else 0 end as activation
from brand),
giftcards as
(select
	  globalKey as brand_id
	, 'Подарочные карты' as sub_module_name
	, case when JSONExtractString(features, 'giftCards') = 'true' then 1 else 0 end as activation
from brand),
lead_form as
(select
	  b.globalKey as brand_id
	, 'Лид форма' as sub_module_name
	, case when s.brand_id is not null then 1 else 0 end as activation
from brand b
left join
(select
	distinct globalKey as brand_id
from shop
where code = 'webForm') s on s.brand_id = b.globalKey),
wallet as
(select
	  b.globalKey as brand_id
	, 'Wallet' as sub_module_name
	, case when mb.brand_id is not null then 1 else 0 end as activation
from brand b
left join
(select
	distinct globalKey as brand_id
from mailing_brand mb
join wallet_mb_list wbl on wbl.mailingBrandId = mb.id
where not isDeleted and channels ilike '%"push": true%') mb on mb.brand_id = b.globalKey),
all_brand as
(select
	  df.brand_id as brand_id
	, df.accountManager as accountManager
	, df.dt as dt
	, df.status as status
	, df.daily_fee as daily_fee
	, m.module_name as module_name
	, m.sub_module_name as sub_module_name
	, m.low_module_name as low_module_name
	, case when m.module_name in ('1. Базовый модуль','2. Аналитика','3. Клиенты') 
		or m.sub_module_name in ('Промокоды','Приведи друга')
		or (m.sub_module_name in ('Автоматические рассылки', 'Ручные рассылки') and (m.low_module_name is null or m.low_module_name = 'SMS'))
	then 1 else
		coalesce(rfm.activation, abadone_cart.activation, offers.activation
		, giftcards.activation, lead_form.activation, wallet.activation, email.activation, viber.activation,0) end as activation
from bi_daily_fee df
left join 
(select
	  c1 as module_name
	, c2 as sub_module_name
	, c3 as low_module_name
from
	values (  ('1. Базовый модуль',null,null)
			, ('2. Аналитика',null,null)
			, ('3. Клиенты',null,null)
			, ('4. Рассылки','Автоматические рассылки',null)
			, ('4. Рассылки','Автоматические рассылки','SMS')
			, ('4. Рассылки','Автоматические рассылки','Push')
			, ('4. Рассылки','Автоматические рассылки','Email')
			, ('4. Рассылки','Автоматические рассылки','Viber')
			, ('4. Рассылки','Ручные рассылки',null)
			, ('4. Рассылки','Ручные рассылки','SMS')
			, ('4. Рассылки','Ручные рассылки','Push')
			, ('4. Рассылки','Ручные рассылки','Email')
			, ('4. Рассылки','Ручные рассылки','Viber')
			, ('4. Рассылки','Брошенные корзины',null)
			--, ('4. Рассылки','Брошенные корзины','Email')
			, ('5. Инструменты','Акции',null)
			, ('5. Инструменты','Промокоды',null)
			, ('5. Инструменты','Приведи друга',null)
			, ('5. Инструменты','Подарочные карты',null)
			, ('6. Прочее','Лид форма',null)
			, ('6. Прочее','Wallet',null)
			, ('6. Прочее','RFM',null)
		   ))
as m on true
left join rfm on rfm.brand_id = df.brand_id and rfm.sub_module_name = m.sub_module_name
left join email on email.brand_id = df.brand_id and email.low_module_name = m.low_module_name
left join viber on viber.brand_id = df.brand_id and viber.low_module_name = m.low_module_name
left join abadone_cart on abadone_cart.brand_id = df.brand_id and abadone_cart.sub_module_name = m.sub_module_name
left join offers on offers.brand_id = df.brand_id and offers.sub_module_name = m.sub_module_name
left join giftcards on giftcards.brand_id = df.brand_id and giftcards.sub_module_name = m.sub_module_name
left join lead_form on lead_form.brand_id = df.brand_id and lead_form.sub_module_name = m.sub_module_name
left join wallet on wallet.brand_id = df.brand_id and wallet.sub_module_name = m.sub_module_name
where df.dt >= '2023-04-01'),
usage_base as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity in ('Client', 'Shop', 'Purchase', 'Report')
group by 1,2),
usage_dash as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'Dashboard'
group by 1,2),
usage_client as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity in ('Client', 'Import' , 'Segment')
group by 1,2),
usage_mailing_auto as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and ((mb.type = 0 and not mb.isDeleted) or oa.entityId is null)
group by 1,2),
usage_mailing_hand as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and ((mb.type = 1 and not mb.isDeleted) or oa.entityId is null)
group by 1,2),
usage_sms_auto as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.channels ilike '%"sms": true%' and not mb.isDeleted and mb.type = 0
group by 1,2),
usage_sms_hand as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.channels ilike '%"sms": true%' and not mb.isDeleted and mb.type = 1
group by 1,2),
usage_push_auto as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.channels ilike '%"push": true%' and not mb.isDeleted and mb.type = 0
group by 1,2),
usage_push_hand as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.channels ilike '%"push": true%' and not mb.isDeleted and mb.type = 1
group by 1,2),
usage_email_auto as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.channels ilike '%"email": true%' and not mb.isDeleted and mb.type = 0
group by 1,2),
usage_email_hand as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.channels ilike '%"email": true%' and not mb.isDeleted and mb.type = 1
group by 1,2),
usage_viber_auto as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.channels ilike '%"viber": true%' and not mb.isDeleted and mb.type = 0
group by 1,2),
usage_viber_hand as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.channels ilike '%"viber": true%' and not mb.isDeleted and mb.type = 1
group by 1,2),
usage_abcarts as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.triggerType in (8,9,10,11) and not mb.isDeleted
group by 1,2),
usage_offer as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'Offer'
group by 1,2),
usage_promocode as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join promocode p on p.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'Promocode'
and ((p.codeType in (0,1) and not p.isDeleted) or oa.entityId is null)
group by 1,2),
usage_friend as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join promocode p on p.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'Promocode'
and p.codeType = 2 and not p.isDeleted
group by 1,2),
usage_giftcards as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity in ('GiftCard', 'GiftCardInstance')
group by 1,2),
usage_rfm as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and JSONExtractString(JSONExtractString(mb.recipients, 'filters'),'conditions') ilike '%rfmsegments%' and not mb.isDeleted
group by 1,2),
usage_lead_form as
(select
	  c.globalKey as brand_id
	, date(c.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from client c
join shop o on o.id = c.issuerShopId
where o.code = 'webForm'
group by 1,2),
usage_wallet as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
left join mailing_brand mb on mb.id = oa.entityId
join wallet_mb_list wbl on wbl.mailingBrandId = mb.id
where oa.operation not ilike '%delete%'
and (o.roles ilike '%role_cashier%' or o.roles ilike '%role_admin%' or o.roles ilike '%role_client_manager%')
and oa.entity = 'MailingBrand'
and mb.channels ilike '%"push": true%' and not mb.isDeleted
group by 1,2),
total as
(select
	  a.brand_id as brand_id
	, a.accountManager as accountManager
	, a.dt as dt
	, case
		when a.status = '0' then 'На интеграции'
		when a.status = '5' then 'Подготовка к запуску'
		when a.status = '1' then 'Активен'
		when a.status = '2' then 'Приостановлен'
		when a.status = '3' then 'Архивный'
		when a.status = '4' then 'Удалён'
		when a.status = '6' then 'Возврат в продажи'
	  else 'Не известный' end as status
	, a.status as status_num
	, a.daily_fee as daily_fee
	, a.module_name as module_name
	, a.sub_module_name as sub_module_name
	, a.low_module_name as low_module_name
	, case
		when a.module_name = '1. Базовый модуль' then 0.8
		when a.module_name = '4. Рассылки' then 0.05
		when a.sub_module_name = 'Акции' then 0.07
		when a.sub_module_name = 'Подарочные карты' then 0.01
		when a.sub_module_name = 'Лид форма' then 0.03
		when a.sub_module_name = 'Wallet' then 0.04
	  end as module_coeff_upper
	, case when coalesce(usms_a.usage_qty, usms_h.usage_qty, up_a.usage_qty, up_h.usage_qty, ue_a.usage_qty, ue_h.usage_qty, uv_a.usage_qty, uv_h.usage_qty
		, uma.usage_qty, umh.usage_qty, ua.usage_qty, uo.usage_qty, upc.usage_qty, uf.usage_qty, ug.usage_qty, ur.usage_qty, ul.usage_qty, uw.usage_qty
		, ub.usage_qty, ud.usage_qty, uc.usage_qty, 0) > 0 then 1 else a.activation end as activation
	, coalesce(usms_a.usage_qty, usms_h.usage_qty, up_a.usage_qty, up_h.usage_qty, ue_a.usage_qty, ue_h.usage_qty, uv_a.usage_qty, uv_h.usage_qty
		, uma.usage_qty, umh.usage_qty, ua.usage_qty, uo.usage_qty, upc.usage_qty, uf.usage_qty, ug.usage_qty, ur.usage_qty, ul.usage_qty, uw.usage_qty
		, ub.usage_qty, ud.usage_qty, uc.usage_qty, 0) as usage_qty 
from all_brand a
left join usage_base ub on ub.brand_id = a.brand_id and ub.dt = a.dt and a.module_name = '1. Базовый модуль'
left join usage_dash ud on ud.brand_id = a.brand_id and ud.dt = a.dt and a.module_name = '2. Аналитика'
left join usage_client uc on uc.brand_id = a.brand_id and uc.dt = a.dt and a.module_name = '3. Клиенты'
left join usage_mailing_auto uma on uma.brand_id = a.brand_id and uma.dt = a.dt and a.sub_module_name = 'Автоматические рассылки' and a.low_module_name is null
left join usage_mailing_hand umh on umh.brand_id = a.brand_id and umh.dt = a.dt and a.sub_module_name = 'Ручные рассылки' and a.low_module_name is null
left join usage_sms_auto usms_a on usms_a.brand_id = a.brand_id and usms_a.dt = a.dt and a.low_module_name = 'SMS' and a.sub_module_name = 'Автоматические рассылки'
left join usage_sms_hand usms_h on usms_h.brand_id = a.brand_id and usms_h.dt = a.dt and a.low_module_name = 'SMS' and a.sub_module_name = 'Ручные рассылки'
left join usage_push_auto up_a on up_a.brand_id = a.brand_id and up_a.dt = a.dt and a.low_module_name = 'Push' and a.sub_module_name = 'Автоматические рассылки'
left join usage_push_hand up_h on up_h.brand_id = a.brand_id and up_h.dt = a.dt and a.low_module_name = 'Push' and a.sub_module_name = 'Ручные рассылки'
left join usage_email_auto ue_a on ue_a.brand_id = a.brand_id and ue_a.dt = a.dt and a.low_module_name = 'Email' and a.sub_module_name = 'Автоматические рассылки'
left join usage_email_hand ue_h on ue_h.brand_id = a.brand_id and ue_h.dt = a.dt and a.low_module_name = 'Email' and a.sub_module_name = 'Ручные рассылки'
left join usage_viber_auto uv_a on uv_a.brand_id = a.brand_id and uv_a.dt = a.dt and a.low_module_name = 'Viber' and a.sub_module_name = 'Автоматические рассылки'
left join usage_viber_hand uv_h on uv_h.brand_id = a.brand_id and uv_h.dt = a.dt and a.low_module_name = 'Viber' and a.sub_module_name = 'Ручные рассылки'
left join usage_abcarts ua on ua.brand_id = a.brand_id and ua.dt = a.dt and a.sub_module_name = 'Брошенные корзины'
left join usage_offer uo on uo.brand_id = a.brand_id and uo.dt = a.dt and a.sub_module_name = 'Акции'
left join usage_promocode upc on upc.brand_id = a.brand_id and upc.dt = a.dt and a.sub_module_name = 'Промокоды'
left join usage_friend uf on uf.brand_id = a.brand_id and uf.dt = a.dt and a.sub_module_name = 'Приведи друга'
left join usage_giftcards ug on ug.brand_id = a.brand_id and ug.dt = a.dt and a.sub_module_name = 'Подарочные карты'
left join usage_rfm ur on ur.brand_id = a.brand_id and ur.dt = a.dt and a.sub_module_name = 'RFM'
left join usage_lead_form ul on ul.brand_id = a.brand_id and ul.dt = a.dt and a.sub_module_name = 'Лид форма'
left join usage_wallet uw on uw.brand_id = a.brand_id and uw.dt = a.dt and a.sub_module_name = 'Wallet'),
prefinal as
(select
	  t.brand_id as brand_id
	, b.name as brand_name
	, i.industry as industry
	, s.soft as soft
	, t.accountManager as accountManager
	, t.dt as dt
	, t.status as status
	, t.status_num as status_num
	, t.module_coeff_upper as module_coeff_upper
	, t.module_name as module_name
	, t.sub_module_name as sub_module_name
	, t.low_module_name as low_module_name
	, case 
		when t.sub_module_name in ('Акции', 'Подарочные карты', 'Лид форма', 'Wallet', 'Автоматические рассылки','Ручные рассылки') then concat(t.module_name, t.sub_module_name)
		when t.module_name in ('1. Базовый модуль') then t.module_name
	  else null end as module_coeff_base
	, case 
		when t.sub_module_name in ('Акции', 'Подарочные карты', 'Лид форма', 'Wallet','Автоматические рассылки','Ручные рассылки')
			and t.low_module_name is null then concat(t.module_name, t.sub_module_name)
		when t.module_name in ('1. Базовый модуль') then t.module_name
	  else null end as module_coeff_base_agg
	, t.daily_fee as daily_fee
	, t.activation as activation
	, t.usage_qty as usage_qty
	, case
		when t.module_name = '1. Базовый модуль' then coalesce(r.revenue_base,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name is null then coalesce(r.revenue_sendings_auto,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name is null then coalesce(r.revenue_sendings_hand,0)
		when t.sub_module_name = 'Брошенные корзины' then coalesce(r.revenue_sendings_adcart,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'SMS' then coalesce(r.revenue_sendings_auto_sms,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'SMS' then coalesce(r.revenue_sendings_hand_sms,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'Push' then coalesce(r.revenue_sendings_auto_push,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'Push' then coalesce(r.revenue_sendings_hand_push,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'Email' then coalesce(r.revenue_sendings_auto_email,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'Email' then coalesce(r.revenue_sendings_hand_email,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'Viber' then coalesce(r.revenue_sendings_auto_viber,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'Viber' then coalesce(r.revenue_sendings_hand_viber,0)
		when t.sub_module_name = 'Акции' then coalesce(r.revenue_offer,0)
		when t.sub_module_name = 'Промокоды' then coalesce(r.revenue_promocode,0)
		when t.sub_module_name = 'Приведи друга' then coalesce(r.revenue_promo_friend,0)
		when t.sub_module_name = 'Подарочные карты' then coalesce(r.revenue_gift_card,0)
		when t.sub_module_name = 'RFM' then coalesce(r.revenue_rfm,0)
		when t.sub_module_name = 'Лид форма' then coalesce(r.revenue_lead_form,0)
		when t.sub_module_name = 'Wallet' then coalesce(r.revenue_wallet,0)
	else 0 end as revenue
	, case
		when t.module_name = '1. Базовый модуль' then coalesce(r.lost_sum_base,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name is null then coalesce(r.lost_sum_sendings_auto,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name is null then coalesce(r.lost_sum_sendings_hand,0)
		when t.sub_module_name = 'Брошенные корзины' then coalesce(r.lost_sum_sendings_adcart,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'SMS' then coalesce(r.lost_sum_sendings_auto_sms,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'SMS' then coalesce(r.lost_sum_sendings_hand_sms,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'Push' then coalesce(r.lost_sum_sendings_auto_push,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'Push' then coalesce(r.lost_sum_sendings_hand_push,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'Email' then coalesce(r.lost_sum_sendings_auto_email,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'Email' then coalesce(r.lost_sum_sendings_hand_email,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'Viber' then coalesce(r.lost_sum_sendings_auto_viber,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'Viber' then coalesce(r.lost_sum_sendings_hand_viber,0)
		when t.sub_module_name = 'Акции' then coalesce(r.lost_sum_offer,0)
		when t.sub_module_name = 'Промокоды' then coalesce(r.lost_sum_promocode,0)
		when t.sub_module_name = 'Приведи друга' then coalesce(r.lost_sum_promo_friend,0)
		when t.sub_module_name = 'Подарочные карты' then coalesce(r.lost_sum_gift_card,0)
		when t.sub_module_name = 'RFM' then coalesce(r.lost_sum_rfm,0)
		when t.sub_module_name = 'Лид форма' then coalesce(r.lost_sum_lead_form,0)
		when t.sub_module_name = 'Wallet' then coalesce(r.lost_sum_wallet,0)
	else 0 end as lost_sum
	, case
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name is null then coalesce(lm.sendings_auto_lost_maxma,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name is null then coalesce(lm.sendings_hand_lost_maxma,0)
		when t.sub_module_name = 'Брошенные корзины' then coalesce(lm.sendings_adcart_lost_maxma,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'SMS' then coalesce(lm.sendings_auto_sms_lost_maxma,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'SMS' then coalesce(lm.sendings_hand_sms_lost_maxma,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'Push' then coalesce(lm.sendings_auto_push_lost_maxma,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'Push' then coalesce(lm.sendings_hand_push_lost_maxma,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'Email' then coalesce(lm.sendings_auto_email_lost_maxma,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'Email' then coalesce(lm.sendings_hand_email_lost_maxma,0)
		when t.sub_module_name = 'Автоматические рассылки' and t.low_module_name = 'Viber' then coalesce(lm.sendings_auto_viber_lost_maxma,0)
		when t.sub_module_name = 'Ручные рассылки' and t.low_module_name = 'Viber' then coalesce(lm.sendings_hand_viber_lost_maxma,0)
		when t.sub_module_name = 'RFM' then coalesce(lm.rfm_lost_maxma,0)
		when t.sub_module_name = 'Wallet' then coalesce(lm.wallet_lost_maxma,0)
	else 0 end as lost_maxma
from total t
left join brand b on b.globalKey = t.brand_id
left join ind i on i.brand_id = t.brand_id
left join soft s on s.brand_id = t.brand_id
left join bi_product_moduls_revenue r on r.brand_id = t.brand_id and r.dt = t.dt
left join bi_product_moduls_revenue_lost_maxma lm on lm.brand_id = t.brand_id and lm.dt = t.dt), 
final as 
(select
	  brand_id
	, brand_name
	, industry
	, soft
	, accountManager
	, dt
	, status
	, status_num
	, module_coeff_upper
	, module_name
	, sub_module_name
	, low_module_name
	, module_coeff_base
	, module_coeff_base_agg
	, daily_fee
	, activation
	, usage_qty
	, revenue
	, lost_sum
	, lost_maxma
	, case when module_coeff_base_agg is not null then coalesce(module_coeff_upper * activation,0) * coalesce(
		  case when sub_module_name in ('Автоматические рассылки','Ручные рассылки') then
			case 
				when sum(case when sub_module_name in ('Автоматические рассылки','Ручные рассылки') and low_module_name is null then revenue else 0 end) 
						over (partition by brand_id, dt) = 0 then 0.5 
				else 1.0 * sum(case when low_module_name is null then revenue else 0 end) 
						over (partition by brand_id, dt, sub_module_name)
				/ sum(case when sub_module_name in ('Автоматические рассылки','Ручные рассылки') and low_module_name is null then revenue else 0 end) 
						over (partition by brand_id, dt)
			end
		  end, 1) end as new_module_coeff
	, case when low_module_name is not null then coalesce(activation *
		--case when sub_module_name = 'Брошенные корзины' then 1.0 else
			case when sum(case when low_module_name is not null then revenue else 0 end) over (partition by brand_id, dt, sub_module_name) > 0
				then 1.0 * revenue / sum(case when low_module_name is not null then revenue else 0 end) over (partition by brand_id, dt, sub_module_name)
			else 0.25 end
		--end
		, 0) 
	  end as low_module_coeff
from prefinal),
all_data as
(select
	  brand_id
	, brand_name
	, industry
	, soft
	, accountManager
	, dt
	, status
	, status_num
	, module_name
	, sub_module_name
	, low_module_name
	, activation
	, usage_qty
	, revenue
	, lost_sum
	, lost_maxma
	, case when low_module_name is null then
		coalesce(daily_fee * new_module_coeff / nullif(sum(new_module_coeff) over (partition by brand_id, dt),0),0)
	  else
		coalesce(daily_fee * max(new_module_coeff) over (partition by brand_id, dt, module_coeff_base)
			/ nullif(sum(new_module_coeff) over (partition by brand_id, dt),0) *
		low_module_coeff / nullif(sum(low_module_coeff) over (partition by brand_id, dt, sub_module_name),0),0) 
	  end as daily_fee
from final)
select
	  brand_id
	, brand_name
	, industry
	, soft
	, accountManager
	, dt
	, status
	, status_num
	, case
		when a.module_name = '1. Базовый модуль' then '01. Лояльность'
		when a.sub_module_name = 'Wallet' then '02. Wallet'
		when a.sub_module_name = 'Акции' then '03. Акции'
		when a.module_name = '2. Аналитика' then '05-1. Аналитика'
		when a.sub_module_name = 'RFM' then '05-2. RFM'
		when a.sub_module_name = 'Брошенные корзины' then '06. Брошенные корзины'
		when a.sub_module_name = 'Подарочные карты' then '07. Подарочные карты'
		when a.sub_module_name = 'Приведи друга' then '08. Приведи друга'
		when a.sub_module_name = 'Промокоды' then '09. Промокоды'
		when a.module_name = '3. Клиенты' then '10. CDP'
		when a.sub_module_name = 'Лид форма' then '11. Форма регистрации'
		when a.module_name = '4. Рассылки' then '04. Рассылки'
	  else a.module_name end as module_name
	, case
		when a.module_name = '1. Базовый модуль' then 'Лояльность'
		when a.module_name = '2. Аналитика' then 'Аналитика'
		when a.module_name = '3. Клиенты' then 'CDP'
		when a.sub_module_name = 'Лид форма' then 'Форма регистрации'
	  else a.sub_module_name end as sub_module_name
	, low_module_name
	, activation
	, usage_qty
	, revenue
	, lost_sum
	, lost_maxma
	, daily_fee
	, sum(daily_fee) over (partition by brand_id, a.module_name, a.sub_module_name, low_module_name order by dt) as module_ltv
	, sum(case when daily_fee > 0 then 1 else 0 end) over (partition by brand_id, a.module_name, a.sub_module_name, low_module_name order by dt) as module_lt
	, coalesce(brd1.releaseDate, brd2.releaseDate) as release_dt
from all_data a
left join bi_module_release_date brd1 on brd1.name = module_name
left join bi_module_release_date brd2 on brd2.name = sub_module_name
order by 1,9,10,11,6;

select * from bi_product_moduls;
------


----
--Новый отчёт по продажам
----

--Расчёт дневного CR в разрезе менеджеров продаж и каналов привлечения 
drop table bi_daily_CR_sales_manager_and_lead_type;	  
create live view bi_daily_CR_sales_manager_and_lead_type with refresh 14400 as
with t00 as
(select bdf.brand_id, bdf.dt, bdvs.v_start_days from bi_daily_fee bdf
left join bi_daily_v_start bdvs on bdvs.dt = bdf.dt and bdvs.brand_id = bdf.brand_id),
t0 as 
(select dt, median(v_start_days) as v_st from t00 group by 1),
cr_win as
(select
	  dt
	, toInt64((median(v_st) over (order by dt rows between 90 preceding and current row))) + 7 as cr_window
from t0),
started_brands as
(select 
	  b.dt as dt
	, case 
		when c.cr_window <=10 or c.cr_window is null then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 10 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=15 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 15 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=20 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 20 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=25 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 25 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=30 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 30 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=35 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 35 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=40 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 40 preceding and current row) > 0 
				then b.brand_id else null end
	    when c.cr_window <=45 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 45 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=50 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 50 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=55 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 55 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=60 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 60 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=65 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 65 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=70 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 70 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=75 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 75 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=80 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 80 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=85 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 85 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=90 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 90 preceding and current row) > 0 
				then b.brand_id else null end
		when c.cr_window <=95 then
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 95 preceding and current row) > 0 
				then b.brand_id else null end
		else
		case when
			sum(b.start_flag) over (partition by b.brand_id order by b.dt rows between 100 preceding and current row) > 0 
				then b.brand_id else null end 
		end as brand_id
from bi_starts_detailed b
left join cr_win c on c.dt = b.dt)
select
	  salesManager
	, lead_type
	, dt
	, case when (brand_int + brand_starts) > 0 then 1.0 * brand_starts / (brand_int + brand_starts) else null end as CR
	, brand_int
	, brand_starts
from
(select
	  salesManager
	, lead_type
	, dt
	, count(distinct brand_int) as brand_int
	, count(distinct brand_starts) as brand_starts
from 
(select
	  sd.salesManager as salesManager
	, case 
		when JSONExtractString(b.settings, 'leadType') = 'traffic' then 'Входящий'
		when JSONExtractString(b.settings, 'leadType') = 'sales' then 'Активная продажа'
		when JSONExtractString(b.settings, 'leadType') = 'partner' then 'По рекомендации'
	  else 'Не определён' end as lead_type
	, sd.dt as dt
	, case
	  when c.cr_window <=10 or c.cr_window is null then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 10 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=15 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 15 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=20 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 20 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=25 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 25 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=30 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 30 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=35 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 35 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=40 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 40 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=45 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 45 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=50 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 50 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=55 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 55 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=60 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 60 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=65 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 65 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=70 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 70 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=75 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 75 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=80 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 80 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=85 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 85 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=90 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 90 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  when c.cr_window <=95 then
		  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 95 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  else
	  	  case when 
			min(case when sd.status_int in (0,5) then 0 else 1 end) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) = 0 and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) >= c.cr_window and
			max(sd.days_on_int) over (partition by sd.brand_id order by sd.dt rows between 100 preceding and current row) <= 120
			and sb.brand_id is null then sd.brand_id else null end
	  end as brand_int
	, sb.brand_id as brand_starts
from bi_starts_detailed sd
left join started_brands sb on sb.brand_id = sd.brand_id and sb.dt = sd.dt
left join cr_win c on c.dt = sd.dt
left join brand b on b.globalKey = sd.brand_id) t group by 1,2,3) tt
where salesManager is not null;

select * from bi_daily_CR_sales_manager_and_lead_type;

--Сводные данные для отчёта
drop table bi_daily_sales_manager_report;
create live view bi_daily_sales_manager_report with refresh 14400 as
with t0 as
(select
	  brand_id
	, dt
	, monthly_fee
	, LTV
	, LT_sales_manager
	, case when any(monthly_fee) over (partition by brand_id order by dt rows between 1 following and 1 following) = 0 
		then case when monthly_fee = 0 then null else monthly_fee end else null end as last_not_null_fee
	, case when status in (2,3,4) and 
		(any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) < 2 or
		any(status) over (partition by brand_id order by dt rows between 1 preceding and 1 preceding) > 4)
	  then dt else null end as lost_stopped_dt
from bi_daily_brand_data),
t as
(select
	  brand_id
	, dt as dt
	, LTV
	, LT_sales_manager
	, lost_stopped_dt as lost_stopped_dt
	, case when dt = lost_stopped_dt then 
		last_value(last_not_null_fee) over (partition by brand_id order by dt rows between unbounded preceding and current row) 
	  else null end as last_fee
from t0),
f as
(select 
	  distinct
	  brand_id
	, first_value(fee_value_forecast) over (partition by brand_id order by dt desc) as fee_value_forec
from bi_daily_brand_clients
where fee_value_forecast is not null),
tf as
(select
	  distinct
	  brand_id
	, first_value(tariff_fee) over (partition by brand_id order by dt desc) as tariff_fee
from (select brand_id, dt, sum(tariff_fee) as tariff_fee from bi_daily_tariff_module group by 1,2) t
where t.tariff_fee is not null)
select
	  sd.brand_id as brand_id
	, sd.brand_name as brand_name
	, case 
		when JSONExtractString(b.settings, 'leadType') = 'traffic' then 'Входящий'
		when JSONExtractString(b.settings, 'leadType') = 'sales' then 'Активная продажа'
		when JSONExtractString(b.settings, 'leadType') = 'partner' then 'По рекомендации'
	  else 'Не определён' end as lead_type
	, sd.salesManager as salesManager
	, case when op.username is not null then true else false end as active_manager
	, sd.dt as dt
	, case when sd.int_start_dt = sd.dt then 1 else 0 end as contract
	, case when sd.int_start_dt = sd.dt then coalesce(f.fee_value_forec, tf.tariff_fee) else 0 end as contract_fee
	, case when sd.start_dt = sd.dt then 1 else 0 end as started
	, case when sd.start_dt = sd.dt then sd.fee_start else 0 end as started_fee
	, case when sd.start_dt = sd.dt then sd.fee_start_first else 0 end as started_fee_first
	, case when sd.start_dt = sd.dt then sd.days_on_int else null end as days_on_int
	, t.LTV as LTV
	, t.LT_sales_manager as LT
	, case when t.lost_stopped_dt = sd.dt then 1 else 0 end as lost_stopped
	, t.last_fee as lost_stopped_fee
	, cr.brand_int as brand_int
	, cr.brand_starts as brand_starts
from bi_starts_detailed sd
left join brand b on b.globalKey = sd.brand_id
left join t on t.brand_id = sd.brand_id and t.dt = sd.dt
left join f on f.brand_id = sd.brand_id
left join tf on tf.brand_id = sd.brand_id
left join bi_daily_CR_sales_manager_and_lead_type cr on cr.salesManager = sd.salesManager 
	and cr.lead_type = case 
						when JSONExtractString(b.settings, 'leadType') = 'traffic' then 'Входящий'
						when JSONExtractString(b.settings, 'leadType') = 'sales' then 'Активная продажа'
						when JSONExtractString(b.settings, 'leadType') = 'partner' then 'По рекомендации'
	  					else 'Не определён' end
	and cr.dt = sd.dt
left join (select username from crm_operator where isActive) op on op.username = sd.salesManager;
	
select * from bi_daily_sales_manager_report;

--Когортный отчёт от даты интеграции
drop table bi_daily_sales_manager_report_cohort;
create live view bi_daily_sales_manager_report_cohort with refresh 14400 as
with ltv as
(select
	  brand_id
	, max(LTV_on_date) as LTV_on_date
	, max(LT_on_date) as LT_on_date
from bi_daily_ltv
group by 1),
t as
(select
	  r.brand_id as brand_id
	, r.brand_name as brand_name
	, r.lead_type as lead_type
	, case when r.dt = min(case when r.contract = 1 then r.dt end) over (partition by r.brand_id) then r.dt end as dt_int
	, case when r.dt = min(case when r.contract = 1 then r.dt end) over (partition by r.brand_id) then r.salesManager end as salesManager
	, case when r.dt = min(case when r.contract = 1 then r.dt end) over (partition by r.brand_id) then r.active_manager end as active_manager
	, case when r.dt = min(case when r.contract = 1 then r.dt end) over (partition by r.brand_id) then r.contract end as contract
	, case when r.dt = min(case when r.contract = 1 then r.dt end) over (partition by r.brand_id) then r.contract_fee end as contract_fee
	, case when r.dt = min(case when r.started = 1 then r.dt end) over (partition by r.brand_id) then r.started end as started
	, case when r.dt = min(case when r.started = 1 then r.dt end) over (partition by r.brand_id) then r.started_fee end as started_fee
	, case when r.dt = min(case when r.started = 1 then r.dt end) over (partition by r.brand_id) then r.started_fee_first end as started_fee_first
	, case when r.dt = min(case when r.days_on_int is not null then r.dt end) over (partition by r.brand_id) then r.days_on_int end as days_on_int
	, case when r.dt = min(case when r.lost_stopped = 1 then r.dt end) over (partition by r.brand_id) then r.lost_stopped end as lost_stopped
	, case when r.dt = min(case when r.lost_stopped = 1 then r.dt end) over (partition by r.brand_id) then r.lost_stopped_fee end as lost_stopped_fee
	, l.LTV_on_date as LTV_on_date
	, l.LT_on_date as LT_on_date
from bi_daily_sales_manager_report r
left join ltv l on l.brand_id = r.brand_id)
select
	  brand_id
	, brand_name
	, lead_type
	, max(dt_int) as dt_int
	, max(salesManager) as salesManager
	, max(active_manager) as active_manager
	, max(contract) as contract
	, max(contract_fee) as contract_fee
	, max(started) as started
	, max(started_fee) as started_fee
	, max(started_fee_first) as started_fee_first
	, max(days_on_int) as days_on_int
	, max(lost_stopped) as lost_stopped
	, max(lost_stopped_fee) as lost_stopped_fee
	, max(LTV_on_date) as LTV_on_date
	, max(LT_on_date) as LT_on_date
from t
group by 1,2,3;

select * from bi_daily_sales_manager_report_cohort;


--Таблица по сотрудникам по месяцам
drop table bi_monthly_account_manager_data;
create live view bi_monthly_account_manager_data with refresh 14400 as
with t00 as
(select
	  brand_id
	, accountManager
	, dt
	, date_trunc('month', date_trunc('month', dt) + 35) - 1 as last_mon_dt
	, max(dt) over (partition by brand_id) as last_dt 
	, status
	, monthly_fee
	, pilot
	, case when max(case when monthly_fee > 0 then dt end) over (partition by brand_id) <> max(dt) over (partition by brand_id)
		and dt = max(case when monthly_fee > 0 then dt end) over (partition by brand_id) then 1 else 0 end as archived_flag
	, case when status = 2 and monthly_fee > 0 then 1 else 0 end as stopped_flag
from bi_daily_brand_data),
t0 as
(select
	  t.accountManager
	, t.brand_id
	, date_trunc('month', t.dt) as mon
	, count(distinct case when t.status = 1 and (t.dt = t.last_mon_dt or t.dt = t.last_dt) then t.brand_id end) as active_brands
	, count(distinct case when t.status = 5 and (t.dt = t.last_mon_dt or t.dt = t.last_dt) then t.brand_id end) as ready_brands
	, count(distinct case when t.pilot = 1 and (t.dt = t.last_mon_dt or t.dt = t.last_dt) then t.brand_id end) as pilot_brands
	, sum(case when t.status = 1 and (t.dt = t.last_mon_dt or t.dt = t.last_dt) then t.monthly_fee else 0 end) as fee_sum
	, sum(bd.fee_up_rollup) as fee_up_rollup
	, sum(bd.fee_down_rollup) as fee_down_rollup
	, sum(case when t.archived_flag = 1 or t.stopped_flag = 1 then -t.monthly_fee else 0 end) as stopped_archived_fee
	, count(distinct case when t.archived_flag = 1 or t.stopped_flag = 1 then t.brand_id end) as stopped_lost_brands
from t00 t
left join bi_daily_fee_dynamic bd on bd.brand_id = t.brand_id and bd.dt = t.dt
group by 1,2,3),
t as
(select
	  accountManager
	, mon
	, sum(active_brands) as active_brands
	, sum(ready_brands) as ready_brands
	, sum(pilot_brands) as pilot_brands
	, sum(fee_sum) as fee_sum
	, sum(fee_up_rollup) as fee_up_rollup
	, sum(fee_down_rollup) as fee_down_rollup
	, count(distinct case when t0.fee_up_rollup > 1000 then brand_id end) as up_brands
	, count(distinct case when t0.fee_down_rollup < -1000 then brand_id end) as down_brands
	, sum(stopped_archived_fee) as stopped_archived_fee
	, sum(stopped_lost_brands) as stopped_lost_brands
from t0
group by 1,2)
select 
	  accountManager
	, mon
	, active_brands
	, sum(active_brands) over (partition by accountManager order by mon rows between 1 preceding and 1 preceding) as active_brands_pre_mon
	, ready_brands
	, pilot_brands
	, fee_sum
	, sum(fee_sum) over (partition by accountManager order by mon rows between 1 preceding and 1 preceding) as fee_sum_pre_mon
	, fee_up_rollup
	, fee_down_rollup
	, up_brands
	, down_brands
	, stopped_archived_fee
	, stopped_lost_brands
from t;

select * from bi_monthly_account_manager_data;

---------------------------
--Данные по тарифам брендов
---------------------------
--Сейчас абонка бренда считается в зависимости от тарифа и условий по нему
--Логика определения тарифа для бренда немного сложная, так как очень много нормализованных таблиц
--Плюс есть возможность переопределения тарифа. Например, у бренда есть какой-то базовый тариф, но по одному из модулю могут быть индвидуальные условия, эти условия собираем этим скриптом

drop table bi_daily_tariff_module;	  
create live view bi_daily_tariff_module with refresh 14400 as
with tariff_price_fixed_0 as --Собираем прайсы по тарифной сетке
(select
	  id
	, tariffComponentId
	, tariffBrandComponentId
	, createdAt
	, clientsFrom --тариф в зависимости от числа клиентов
	, clientsTo
	, case when tariffBrandComponentId is not null and price is null then
		any(price) over (partition by tariffBrandComponentId order by clientsFrom rows between 1 preceding and 1 preceding)
	  else price end as price
	, pricePerClient
	, discountAmount --скидка в тарифе
	, discountType --тип скидки
from tariff_price),
tariff_price_fixed as
(select
	  id
	, tariffComponentId
	, tariffBrandComponentId
	, createdAt
	, clientsFrom
	, clientsTo
	, price
	, pricePerClient
	, discountAmount
	, discountType
	, any(price) over (partition by coalesce(tariffComponentId, tariffBrandComponentId) 
			order by createdAt, clientsFrom rows between 1 following and 1 following) as price_next
	, any(pricePerClient) over (partition by coalesce(tariffComponentId, tariffBrandComponentId) 
			order by createdAt, clientsFrom rows between 1 following and 1 following) as pricePerClient_next
	, any(discountAmount) over (partition by coalesce(tariffComponentId, tariffBrandComponentId) 
			order by createdAt, clientsFrom rows between 1 following and 1 following) as discountAmount_next
	, any(discountType) over (partition by coalesce(tariffComponentId, tariffBrandComponentId) 
			order by createdAt, clientsFrom rows between 1 following and 1 following) as discountType_next
from tariff_price_fixed_0),
b as --таблица с брендами
(select
	  brand_id
	, dt
	, min(dt) over (partition by brand_id) as min_dt
from bi_daily_fee),
c0 as --собираем кол-во клиентов
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) as dt
	, toInt64(count(distinct id)) as clients
from client
group by 1,2
union all
select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',case when updatedAt < createdAt then createdAt else updatedAt end), 'Europe/Moscow')) as dt
	, toInt64(-count(distinct id)) as clients
from client
where isDeleted = true
group by 1,2),
c as
(select
	  brand_id
	, dt
	, sum(clients) as clients
from c0
group by 1,2),
c1 as
(select 
	  coalesce(b.brand_id, c.brand_id) as brand_id
	, coalesce(b.dt, c.dt) as dt
	, max(b.min_dt) over (partition by coalesce(b.brand_id, c.brand_id)) as min_dt
	, coalesce(c.clients,0) as clients
from b
full join c
	on c.brand_id = b.brand_id and c.dt = b.dt),
c_all0 as
(select
	  brand_id
	, dt
	, min_dt
	, sum(clients) over (partition by brand_id order by dt rows between unbounded preceding and current row) as clients
from c1),
c_all as
(select
	  brand_id
	, dt
	, clients
from c_all0
where dt >= min_dt),
brand_w_clients0 as
(select
	  brand_id as globalKey
	, dt + 1 as dt
	, clients
from c_all),
clients_forecast as --прогноз клиентов для брендов, которые ещё не запущены
(select 
	  bs.brand_id
	, toInt64(JSONExtractString(b.extraFields, 'expectedClientsCount')) as clients_forecast
	, min(bs.fee_start_date) as fee_start_date
from bi_daily_starts bs
left join brand b on b.globalKey = bs.brand_id
group by 1,2),
brand_w_clients as
(select
	  b.globalKey
	, b.dt
	, case when cf.clients_forecast is not null
		then case when cf.fee_start_date > b.dt then cf.clients_forecast else b.clients end
	  else b.clients end as clients
from brand_w_clients0 b
left join clients_forecast cf on cf.brand_id = b.globalKey),
brand_w_tariff as  --получаем для каждого бренда на определённую дату свой тариф
(select
	  bc.*
	, case 
		when bc.dt >= date(bt.dateFrom , 'Europe/Moscow') and bc.dt <= coalesce(date(bt.dateTo, 'Europe/Moscow'),date('2099-12-31'))
	  then bt.tariffId end as tariffId
	, row_number() over (partition by bc.globalKey, bc.dt 
		order by case 
			when bc.dt >= date(bt.dateFrom , 'Europe/Moscow') and bc.dt <= coalesce(date(bt.dateTo, 'Europe/Moscow'),date('2099-12-31')) 
		  then 0 else 1 end --это условие, что тариф в эту дату рабочий (в КХ нельзя делать джойн по неравенству)
		, bt.createdAt desc) as rn --тут бывают задвоения, когда в одну дату есть два тарифа, чтобы дедуплицировать используюем логику, берём самый свежий тариф
from brand_w_clients bc
left join brand_tariff bt on bt.globalKey  = bc.globalKey),
brand_w_tariff_modules as --присоединяем к тарифу информацию по модулям (модули - это составная часть тарифа)
(select
	  bt.globalKey
	, bt.dt
	, bt.clients
	, bt.tariffId
	, case 
		when bt.dt >= date(tc.dateFrom , 'Europe/Moscow') and bt.dt <= coalesce(date(tc.dateTo, 'Europe/Moscow'),date('2099-12-31'))
	  then tc.tariffModuleId end as tariffModuleId
	, case 
		when bt.dt >= date(tc.dateFrom , 'Europe/Moscow') and bt.dt <= coalesce(date(tc.dateTo, 'Europe/Moscow'),date('2099-12-31'))
	  then tc.id end as tariffComponentId
	, row_number() over (partition by bt.globalKey, bt.dt,
		case 
			when bt.dt >= date(tc.dateFrom , 'Europe/Moscow') and bt.dt <= coalesce(date(tc.dateTo, 'Europe/Moscow'),date('2099-12-31'))
	    then tc.tariffModuleId end
		order by case 
			when bt.dt >= date(tc.dateFrom , 'Europe/Moscow') and bt.dt <= coalesce(date(tc.dateTo, 'Europe/Moscow'),date('2099-12-31')) 
		  then 0 else 1 end
		, tc.createdAt desc) as rn --аналогично дедуплицируем модули, берём самый свежий по дате создания
from brand_w_tariff bt
left join tariff_component tc on tc.tariffId = bt.tariffId
where bt.rn = 1),
brand_w_tariff_modules_prices as --к модулям подтягиваем стоимость из прайса, учитываем скидку, если она заполнена, причём учитываем % это или фикс в руб.
(select
	  btm.globalKey
	, btm.dt
	, btm.clients
	, btm.tariffId
	, btm.tariffModuleId
	, btm.tariffComponentId
	, tp.clientsFrom
	, tp.clientsTo
	, tp.pricePerClient
	, tp.pricePerClient_next
	, case 
		when tp.discountType = 1 then concat(toString(discountAmount),'%')
		when tp.discountType = 0 then concat(toString(discountAmount),' руб.')
	  else null end as discount_value
	, (case when coalesce(tp.discountType,0) = 0 then tp.price - 1.0 * coalesce(tp.discountAmount,0) else tp.price * (1 - tp.discountAmount/100.0) end
		+ case when btm.clients > coalesce(tp.clientsFrom,999999999) then 1.0 * (btm.clients - coalesce(tp.clientsFrom,999999999)) * coalesce(tp.pricePerClient,0) else 0 end)
	  * 365 / 12 as tariff_fee
	, (case when coalesce(tp.discountType_next,0) = 0 then tp.price_next - 1.0 * coalesce(tp.discountAmount_next,0) else tp.price_next * (1 - tp.discountAmount_next/100.0) end)
	  * 365 / 12 as tariff_fee_next
	, row_number() over (partition by btm.globalKey, btm.dt, btm.tariffModuleId, btm.tariffComponentId
		order by case when btm.clients >= tp.clientsFrom and btm.clients <= coalesce(tp.clientsTo,999999999) then 0 else 1 end
			, tp.createdAt desc) as rn --аналогично дедупликация
from brand_w_tariff_modules btm
left join tariff_price_fixed tp on tp.tariffComponentId = btm.tariffComponentId
where btm.rn = 1),
brand_w_base_tariff as --финализируем, получаем базовый тариф на дату для каждого бренда в разрезе модулей с ценами и скидками
(select 
	  globalKey
	, dt
	, tariffId
	, tariffModuleId
	, max(clientsFrom) as clientsFrom
	, max(clientsTo) as clientsTo
	, max(pricePerClient) as pricePerClient
	, max(pricePerClient_next) as pricePerClient_next
	, max(discount_value) as discount_value
	, sum(coalesce(tariff_fee,0)) as tariff_fee
	, sum(coalesce(tariff_fee_next,0)) as tariff_fee_next
from brand_w_tariff_modules_prices
where rn = 1
group by 1,2,3,4),
brand_w_non_base_tariff_modules as --тут смотрим уникальные условия по определенным модулям (если они есть у бренда)
(select
	  bc.*
	, case 
		when bc.dt >= date(tc.dateFrom , 'Europe/Moscow') and bc.dt <= coalesce(date(tc.dateTo, 'Europe/Moscow'),date('2099-12-31'))
	  then tc.tariffModuleId end as tariffModuleId
	, case 
		when bc.dt >= date(tc.dateFrom , 'Europe/Moscow') and bc.dt <= coalesce(date(tc.dateTo, 'Europe/Moscow'),date('2099-12-31'))
	  then tc.id end as tariffBrandComponentId
	, row_number() over (partition by bc.globalKey, bc.dt, case 
			when bc.dt >= date(tc.dateFrom , 'Europe/Moscow') and bc.dt <= coalesce(date(tc.dateTo, 'Europe/Moscow'),date('2099-12-31'))
	  	then tc.tariffModuleId end 
		order by case 
			when bc.dt >= date(tc.dateFrom , 'Europe/Moscow') and bc.dt <= coalesce(date(tc.dateTo, 'Europe/Moscow'),date('2099-12-31')) 
		  then 0 else 1 end
		, tc.createdAt desc) as rn --аналогично дедупликация
from brand_w_clients bc
join tariff_brand_component tc on bc.globalKey = tc.globalKey),
brand_w_non_base_tariff_modules_prices as --подтягиваем цены по уникальным условиям модулей
(select
	  btm.globalKey
	, btm.dt
	, btm.clients
	, btm.tariffModuleId
	, btm.tariffBrandComponentId
	, tp.clientsFrom
	, tp.clientsTo
	, tp.pricePerClient
	, tp.pricePerClient_next
	, case 
		when tp.discountType = 1 then concat(toString(discountAmount),'%')
		when tp.discountType = 0 then concat(toString(discountAmount),' руб.')
	  else null end as discount_value
	, (case when coalesce(tp.discountType,0) = 0 then tp.price - 1.0 * coalesce(tp.discountAmount,0) else tp.price * (1 - tp.discountAmount/100.0) end
		+ case when btm.clients > coalesce(tp.clientsFrom,999999999) then 1.0 * (btm.clients - coalesce(tp.clientsFrom,999999999)) * coalesce(tp.pricePerClient,0) else 0 end)
	  * 365 / 12 as tariff_fee
	, (case when coalesce(tp.discountType_next,0) = 0 then tp.price_next - 1.0 * coalesce(tp.discountAmount_next,0) else tp.price_next * (1 - tp.discountAmount_next/100.0) end)
	  * 365 / 12 as tariff_fee_next
	, row_number() over (partition by btm.globalKey, btm.dt, btm.tariffModuleId, btm.tariffBrandComponentId
		order by case when btm.clients >= tp.clientsFrom and btm.clients <= coalesce(tp.clientsTo,999999999) then 0 else 1 end
			, tp.createdAt desc) as rn --аналогично дедупликация
from brand_w_non_base_tariff_modules btm
left join tariff_price_fixed tp on tp.tariffBrandComponentId = btm.tariffBrandComponentId
where btm.rn = 1 and btm.tariffModuleId is not null), --плюс условие, что такой уникальный модуль существует
brand_w_non_base_tariff as --финализируем, получаем уникальный тариф по модулю на дату для каждого бренда, если есть спец условия
(select 
	  globalKey
	, dt
	, tariffModuleId
	, max(clientsFrom) as clientsFrom
	, max(clientsTo) as clientsTo
	, max(pricePerClient) as pricePerClient
	, max(pricePerClient_next) as pricePerClient_next
	, max(discount_value) as discount_value
	, sum(coalesce(tariff_fee,0)) as tariff_fee
	, sum(coalesce(tariff_fee_next,0)) as tariff_fee_next
from brand_w_non_base_tariff_modules_prices
where rn = 1 --аналогично дедупликация
group by 1,2,3)
select --тут уже соединяем данные по базовому тарифу и по уникальным условиям модулей - уникальные условия должны перезаписывать базовые условия по тарифу
	  coalesce(bnt.globalKey, bt.globalKey) as brand_id
	, coalesce(bnt.dt, bt.dt) as dt
	, coalesce(t.name, 'Свой тариф') as tariff_name
	, coalesce(tm.name, 'Нет модуля') as tariff_module_name
	, case when bnt.tariffModuleId is not null then coalesce(bnt.clientsTo, bnt.clientsFrom) 
		else coalesce(bt.clientsTo, bt.clientsFrom) end as clientsTo
	, case when bnt.tariffModuleId is not null then bnt.pricePerClient else bt.pricePerClient end * 365/12 as pricePerClient
	, case when bnt.tariffModuleId is not null then bnt.pricePerClient_next else bt.pricePerClient_next end * 365/12 as pricePerClient_next
	, coalesce(bnt.discount_value, bt.discount_value) as discount_value
	, sum(coalesce(bnt.tariff_fee, bt.tariff_fee, 0)) as tariff_fee
	, sum(coalesce(bnt.tariff_fee_next, bt.tariff_fee_next, 0)) as tariff_fee_next
from brand_w_base_tariff bt
full join brand_w_non_base_tariff bnt on bt.globalKey = bnt.globalKey and bt.dt = bnt.dt and bt.tariffModuleId = bnt.tariffModuleId
left join tariff_module tm on tm.id = coalesce(bnt.tariffModuleId, bt.tariffModuleId)
left join tariff t on t.id = bt.tariffId
group by 1,2,3,4,5,6,7,8
order by 1,2,3,4,5,6,7,8;

select * from bi_daily_tariff_module;


--Отчёт по атрибутам брендов (BI-85)
--Тут отчёт для детальной оценки по тарифам, чтобы можно было видеть модули, которые подулючены в тарифах у бренда и их условия
drop table bi_brand_and_tariff;	  
create live view bi_brand_and_tariff with refresh 14400 as
with md as
(select
	max(dt) as max_date
from bi_daily_fee),
brand_data as
(select
	  brand_id
	, dt
	, arrayStringConcat(groupUniqArray(industry),', ') as industry
	, arrayStringConcat(groupUniqArray(soft),', ') as soft
	, max(shops_qty) as shops_qty
from bi_product_target_group
group by 1,2),
client_data as
(select 
	  c.globalKey as brand_id
	, count(distinct c.id) as clients_qty
	, count(distinct w.clientId) as clients_w_wallet_qty
from client c
left join (select distinct clientId from wallet_card) w on w.clientId = c.id
where not c.isDeleted
group by 1)
select
	  distinct
	  b.name as brand_name
	, case
		when status = '0' then 'На интеграции'
		when status = '5' then 'Подготовка к запуску'
		when status = '1' then 'Активен'
		when status = '2' then 'Приостановлен'
		when status = '3' then 'Архивный'
		when status = '4' then 'Удалён'
		when status = '6' then 'Возврат в продажи'
	  else 'Не известный' end as status
	, coalesce(bbm.accountManager,'Не назначен') as accountManager
	, bd.industry as industry
	, coalesce(cd.clients_qty,0) as clients_qty
	, coalesce(cd.clients_w_wallet_qty,0) as clients_w_wallet_qty
	, coalesce(max(case when btm.tariff_module_name = 'Платформа' then btm.tariff_name end) over (partition by b.globalKey),'Свой тариф') as tariff_name
	, coalesce(round(sum(btm.tariff_fee) over (partition by b.globalKey)),0) as tariff_fee
	, coalesce(bf.fee,0) as fee
	, coalesce(round(b.balance),0) + coalesce(round(b.giftBalance),0) as balance
	, b.balanceThreshold as balanceThreshold
	, JSONExtractString(b.settings, 'autoSuspend') as autoSuspend
	, coalesce(bl.LT_on_date,0) as LT
	, bd.shops_qty as shops_qty
	, bd.soft as soft
	, bbm.projectManager as projectManager
	, max(case when btm.tariff_module_name = 'Форма регистрации' then true else false end) over (partition by b.globalKey) as module_form
	, max(case when btm.tariff_module_name = 'Карты Wallet' then true else false end) over (partition by b.globalKey) as module_wallet_card
	, max(case when btm.tariff_module_name = 'Email-конструктор' then true else false end) over (partition by b.globalKey) as module_email
	, max(case when btm.tariff_module_name = 'Акции' then true else false end) over (partition by b.globalKey) as module_offer
	, max(case when btm.tariff_module_name = 'SmartRFM' then true else false end) over (partition by b.globalKey) as module_smart_rfm
	, max(case when btm.tariff_module_name = 'Подарочные карты' then true else false end) over (partition by b.globalKey) as module_gift_card
	, max(case when btm.tariff_module_name = 'Сопровождение' then true else false end) over (partition by b.globalKey) as module_marketing_support
	, max(case when btm.tariff_module_name = 'Выгрузка по ТЗ клиента (на FTP и т.д.)' then true else false end) over (partition by b.globalKey) as module_custom_report
	, max(case when btm.tariff_module_name = 'Коннектор IIKO' then true else false end) over (partition by b.globalKey) as module_iiko
	, max(case when btm.tariff_module_name = 'Блок ecommerce' then true else false end) over (partition by b.globalKey) as module_ecommerce
	, max(case when btm.tariff_module_name = 'Подпись SMS' then true else false end) over (partition by b.globalKey) as module_sms_signature
	, max(case when btm.tariff_module_name = 'Дополнительное имя отправителя' then true else false end) over (partition by b.globalKey) as module_extra_sender
	, max(case when btm.tariff_module_name = 'Telegram-бот' then true else false end) over (partition by b.globalKey) as module_tg_bot
from brand b, md
left join bi_brand_managers bbm on bbm.brand_id = b.globalKey and bbm.dt = md.max_date
left join brand_data bd on bd.brand_id = b.globalKey and bd.dt = md.max_date
left join client_data cd on cd.brand_id = b.globalKey
left join bi_daily_tariff_module btm on btm.brand_id = b.globalKey and btm.dt = md.max_date
left join bi_daily_fee bf on bf.brand_id = b.globalKey and bf.dt = md.max_date
left join bi_daily_ltv bl on bl.brand_id = b.globalKey and bl.dt = md.max_date;


select * from bi_brand_and_tariff;

------
--Оценка потенциала развития базы (BI-92)
------
drop table bi_brands_potential;	  
create live view bi_brands_potential with refresh 14400 as
with max_dt as
(select
	max(dt) as max_dt
from bi_daily_fee),
wallet_clients as
(select 
	distinct clientId 
from wallet_card),
b as
(select
	  brand_id
	, dt
	, min(dt) over (partition by brand_id) as min_dt
from bi_daily_fee),
c0 as
((select
	  c.globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',c.createdAt), 'Europe/Moscow')) as dt
	, toInt64(count(distinct c.id)) as clients
	, toInt64(count(distinct w.clientId)) as clients_wallet
from client c
left join wallet_clients w on w.clientId = c.id
group by 1,2)
union all
(select
	  c.globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',case when c.updatedAt < c.createdAt then c.createdAt else c.updatedAt end), 'Europe/Moscow')) as dt
	, toInt64(-count(distinct c.id)) as clients
	, toInt64(-count(distinct w.clientId)) as clients_wallet
from client c
left join wallet_clients w on w.clientId = c.id
where c.isDeleted = true
group by 1,2)
),
c as
(select
	  brand_id
	, dt
	, sum(clients) as clients
	, sum(clients_wallet) as clients_wallet
from c0
group by 1,2),
c1 as
(select 
	  coalesce(b.brand_id, c.brand_id) as brand_id
	, coalesce(b.dt, c.dt) as dt
	, max(b.min_dt) over (partition by coalesce(b.brand_id, c.brand_id)) as min_dt
	, coalesce(c.clients,0) as clients
	, coalesce(c.clients_wallet,0) as clients_wallet
from b
full join c
	on c.brand_id = b.brand_id and c.dt = b.dt),
c_all0 as
(select
	  brand_id
	, dt
	, min_dt
	, sum(clients) over (partition by brand_id order by dt rows between unbounded preceding and current row) as clients
	, sum(clients_wallet) over (partition by brand_id order by dt rows between unbounded preceding and current row) as clients_wallet
from c1),
c_all as
(select
	  brand_id
	, dt
	, clients
	, clients_wallet
from c_all0
where dt >= min_dt),
brand_w_clients0 as
(select
	  brand_id as globalKey
	, dt + 1 as dt
	, clients
	, clients_wallet
from c_all),
clients_forecast as
(select 
	  bs.brand_id
	, toInt64(JSONExtractString(b.extraFields, 'expectedClientsCount')) as clients_forecast
	, min(bs.fee_start_date) as fee_start_date
from bi_daily_starts bs
left join brand b on b.globalKey = bs.brand_id
group by 1,2),
brands_w_clients as
(select
	  b.globalKey as brand_id
	, b.dt
	, case when cf.clients_forecast is not null
		then case when cf.fee_start_date > b.dt then cf.clients_forecast else b.clients end
	  else b.clients end as clients
	, b.clients_wallet
from brand_w_clients0 b
left join clients_forecast cf on cf.brand_id = b.globalKey),
brands_w_clients_6_mon_raw as
(select
	  b.brand_id
	, b.dt
	, b.clients - 
		any(b.clients) over (partition by b.brand_id order by b.dt rows between 1 preceding and 1 preceding) as clients_daily_growth
from brands_w_clients b, max_dt m
where dt >= m.max_dt - 180),
brands_w_clients_6_mon as
(select
	  brand_id
	, 30.0 * avg(clients_daily_growth) as monthly_clients_growth
from brands_w_clients_6_mon_raw
group by 1),
purchase_all as
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) as dt
	, sum(paidAmount) as revenue
from purchase
group by 1,2),
purchase_6_mon as
(select
	  brand_id
	, 30.0 * avg(revenue) as monthly_revenue
from purchase_all p, max_dt m
where dt >= m.max_dt - 180
group by 1),
bi_daily_fee_wo_0 as
(select
	  bf.*
	, max(bf.dt) over (partition by bf.brand_id) as max_dt
	, bs.fee_start_date
from bi_daily_fee bf
left join (select brand_id, min(fee_start_date + 30) as fee_start_date
		from bi_daily_starts group by 1) bs on bs.brand_id = bf.brand_id
where bf.fee > 0),
fee_dynamics as
(select
	  brand_id
	, avg(case when year(dt) = 2022 then fee end) -
		max(case when (fee_start_date <= '2022-01-01' and dt = '2022-01-01') or (fee_start_date = dt) then fee end) as fee_dynamic_2022
	, avg(case when year(dt) = 2023 then fee end) -
		max(case when (fee_start_date <= '2023-01-01' and dt = '2023-01-01') or (fee_start_date = dt) then fee end) as fee_dynamic_2023
	, avg(case when year(dt) = 2024 then fee end) -
		max(case when (fee_start_date <= '2024-01-01' and dt = '2024-01-01') or (fee_start_date = dt) then fee end) as fee_dynamic_2024
	, max(case when dt = max_dt then fee end) - max(case when fee_start_date = dt then fee end) as fee_dynamic
from bi_daily_fee_wo_0
group by 1),
tariffs as
(select
	  t.brand_id as brand_id
	, coalesce(max(case when t.tariff_module_name = 'Платформа' then t.tariff_name end),'Свой тариф') as tariff_name
	, sum(t.tariff_fee) as current_tariff
	, max(t.clientsTo) as upper_clients_border
	, sum(case when t.tariff_fee > 0 and t.tariff_fee_next = 0 then t.tariff_fee else t.tariff_fee_next end) as next_tariff
	, max(t.pricePerClient) as price_per_client
	, max(case when t.pricePerClient_next is null and t.pricePerClient is not null 
		then t.pricePerClient else t.pricePerClient_next end) as next_price_per_client
from bi_daily_tariff_module t, max_dt m
where t.dt = m.max_dt
group by 1)
select
	  t.brand_id as brand_id
	, b.name as brand_name
	, case
		when b.status = '0' then 'На интеграции'
		when b.status = '5' then 'Подготовка к запуску'
		when b.status = '1' then 'Активен'
		when b.status = '2' then 'Приостановлен'
		when b.status = '3' then 'Архивный'
		when b.status = '4' then 'Удалён'
		when b.status = '6' then 'Возврат в продажи'
	  else 'Не известный' end as status_name
	, lt.accountManager as accountManager
	, lt.LT_on_date as LT
	, c.clients as clients
	, case when c.clients_wallet > c.clients then c.clients else c.clients_wallet end as clients_wallet
	, t.tariff_name as tariff_name
	, t.current_tariff as current_tariff
	, t.upper_clients_border as upper_clients_border
	, t.next_tariff as next_tariff
	, t.price_per_client as price_per_client
	, t.next_price_per_client as next_price_per_client
	, c6.monthly_clients_growth as monthly_clients_growth
	, fd.fee_dynamic_2022 as fee_dynamic_2022
	, fd.fee_dynamic_2023 as fee_dynamic_2023
	, fd.fee_dynamic_2024 as fee_dynamic_2024
	, fd.fee_dynamic as fee_dynamic
	, p.monthly_revenue as monthly_revenue
from tariffs t, max_dt m
left join brand b on b.globalKey = t.brand_id
left join bi_daily_ltv lt on lt.brand_id = t.brand_id and lt.dt = m.max_dt
left join brands_w_clients c on c.brand_id = t.brand_id and c.dt = m.max_dt
left join brands_w_clients_6_mon c6 on c6.brand_id = t.brand_id
left join fee_dynamics fd on fd.brand_id = t.brand_id
left join purchase_6_mon p on p.brand_id = t.brand_id;

select * from bi_brands_potential where brand_name ilike '%комода%';
select * from tariff_price where tariffBrandComponentId = '718e2f35-8881-4806-99c4-db7ecfe61573';

------
--Оценка потенциала критичности базы (BI-93)
------

drop table bi_brands_criticality;	  
create live view bi_brands_criticality with refresh 14400 as
with max_dt as
(select
	max(dt) as max_dt
from bi_daily_fee),
wallet_clients as
(select 
	distinct clientId 
from wallet_card),
b as
(select
	  brand_id
	, dt
	, min(dt) over (partition by brand_id) as min_dt
from bi_daily_fee),
c0 as
((select
	  c.globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',c.createdAt), 'Europe/Moscow')) as dt
	, toInt64(count(distinct c.id)) as clients
	, toInt64(count(distinct w.clientId)) as clients_wallet
from client c
left join wallet_clients w on w.clientId = c.id
group by 1,2)
union all
(select
	  c.globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',case when c.updatedAt < c.createdAt then c.createdAt else c.updatedAt end), 'Europe/Moscow')) as dt
	, toInt64(-count(distinct c.id)) as clients
	, toInt64(-count(distinct w.clientId)) as clients_wallet
from client c
left join wallet_clients w on w.clientId = c.id
where c.isDeleted = true
group by 1,2)
),
c as
(select
	  brand_id
	, dt
	, sum(clients) as clients
	, sum(clients_wallet) as clients_wallet
from c0
group by 1,2),
c1 as
(select 
	  coalesce(b.brand_id, c.brand_id) as brand_id
	, coalesce(b.dt, c.dt) as dt
	, max(b.min_dt) over (partition by coalesce(b.brand_id, c.brand_id)) as min_dt
	, coalesce(c.clients,0) as clients
	, coalesce(c.clients_wallet,0) as clients_wallet
from b
full join c
	on c.brand_id = b.brand_id and c.dt = b.dt),
c_all0 as
(select
	  brand_id
	, dt
	, min_dt
	, sum(clients) over (partition by brand_id order by dt rows between unbounded preceding and current row) as clients
	, sum(clients_wallet) over (partition by brand_id order by dt rows between unbounded preceding and current row) as clients_wallet
from c1),
c_all as
(select
	  brand_id
	, dt
	, clients
	, clients_wallet
from c_all0
where dt >= min_dt),
brand_w_clients0 as
(select
	  brand_id as globalKey
	, dt + 1 as dt
	, clients
	, clients_wallet
from c_all),
clients_forecast as
(select 
	  bs.brand_id
	, toInt64(JSONExtractString(b.extraFields, 'expectedClientsCount')) as clients_forecast
	, min(bs.fee_start_date) as fee_start_date
from bi_daily_starts bs
left join brand b on b.globalKey = bs.brand_id
group by 1,2),
brands_w_clients as
(select
	  b.globalKey as brand_id
	, b.dt
	, case when cf.clients_forecast is not null
		then case when cf.fee_start_date > b.dt then cf.clients_forecast else b.clients end
	  else b.clients end as clients
	, b.clients_wallet
from brand_w_clients0 b
left join clients_forecast cf on cf.brand_id = b.globalKey),
base_table as
(select
	  f.brand_id as brand_id
	, b.name as brand_name
	, f.dt as dt
	, JSONExtractString(JSONExtractString(b.settings, 'accountManager'),'username') as accountManager
	, case
		when b.status = '0' then 'На интеграции'
		when b.status = '5' then 'Подготовка к запуску'
		when b.status = '1' then 'Активен'
		when b.status = '2' then 'Приостановлен'
		when b.status = '3' then 'Архивный'
		when b.status = '4' then 'Удалён'
		when b.status = '6' then 'Возврат в продажи'
	  else 'Не известный' end as status_name
	, f.daily_fee as daily_fee
from bi_daily_fee f
left join brand b on b.globalKey = f.brand_id),
revenue as
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) as dt
	, sum(paidAmount) as revenue
	, sum(case when mailingBrandId is not null or bonusesApplied > 0 or bonusesCollected > 0
			or offerDiscount > 0 or promocodeDiscount > 0 or bonusesDiscount > 0 then paidAmount else 0 end) as pl_revenue
	, count(distinct id) as orders
	, count(distinct case when bonusesApplied > 0 or bonusesCollected > 0 then id end) as pl_orders
from purchase
group by 1,2),
offer_raw as
(select
	  globalKey as brand_id
	, concat(toString(globalKey),'__', toString(id)) as offer_synth_id
	, coalesce(date(date_trunc('day',date_trunc('hour',availableFrom), 'Europe/Moscow'))
		, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow'))) as dt_from
	, coalesce(date(date_trunc('day',date_trunc('hour',availableTo), 'Europe/Moscow')), date('2099-12-31')) as dt_to
from offer
where not isDeleted and isActive),
offer_w_base as
(select
	  b.brand_id as brand_id
	, b.brand_name as brand_name
	, b.dt as dt
	, b.accountManager as accountManager
	, b.status_name as status_name
	, o.offer_synth_id as offer_synth_id
	, o.dt_from as dt_from
	, o.dt_to as dt_to
from base_table b
left join offer_raw o on o.brand_id = b.brand_id
where o.brand_id is not null),
offer_final as
(select
	  brand_id
	, brand_name
	, dt
	, accountManager
	, status_name
	, offer_synth_id
	, dt_from as dt_offer_start
from offer_w_base
where dt >= dt_from and dt <= dt_to),
sendings as
(select
	  globalKey as brand_id
	, concat(toString(globalKey),'__', toString(id)) as sending_synth_id
	, coalesce(date(date_trunc('day',date_trunc('hour',scheduledAt), 'Europe/Moscow'))
		, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow'))) as dt
from mailing_brand
where not isDeleted and isActive),
sendings_total as
(select
	  brand_id
	, dt
	, count(distinct sending_synth_id) as sendings_qty
from sendings
group by 1,2),
analytics as
(select
	  oa.globalKey as brand_id
	, date(oa.createdAt + 3*3600) as dt
	, count(*) as usage_qty
from operator_audit oa
left join operator o on o.id = oa.operatorId
where oa.operation not ilike '%delete%'
and o.roles ilike '%role_admin%'
and oa.entity = 'Dashboard'
group by 1,2),
o as
(select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',createdAt), 'Europe/Moscow')) as dt
	, toInt64(count(distinct id)) as operators
from operator
where not (roles ilike '%role_crm_%' or roles ilike '%role_super_admin%' or roles ilike '%role_super_user%')
group by 1,2
union all
select
	  globalKey as brand_id
	, date(date_trunc('day',date_trunc('hour',case when updatedAt < createdAt then createdAt else updatedAt end), 'Europe/Moscow')) as dt
	, toInt64(-count(distinct id)) as operators
from operator
where not (roles ilike '%role_crm_%' or roles ilike '%role_super_admin%' or roles ilike '%role_super_user%')
and isDeleted
group by 1,2),
o_agg as
(select
	  brand_id
	, dt
	, sum(operators) as operators
from o
group by 1,2),
o_total as
(select 
	  coalesce(b.brand_id, o.brand_id) as brand_id
	, coalesce(b.dt, o.dt) as dt
	, coalesce(o.operators,0) as operators
from base_table b
full join o_agg o
	on o.brand_id = b.brand_id and o.dt = b.dt),
operators_agg as
(select
	  brand_id
	, dt
	, sum(operators) over (partition by brand_id order by dt rows between unbounded preceding and current row) as operators
from o_total),
total as 
(select 
	  b.brand_id as brand_id
	, b.brand_name as brand_name
	, b.accountManager as accountManager
	, b.dt as dt
	, b.status_name as status_name
	, b.daily_fee as daily_fee
	, lt.LT_on_date as LT
	, coalesce(c.clients,0) as clients
	, coalesce(r.revenue,0) as revenue
	, coalesce(r.pl_revenue,0) as pl_revenue
	, coalesce(r.orders,0) as orders
	, coalesce(r.pl_orders,0) as pl_orders
	, coalesce(s.sendings_qty,0) as sendings_qty
	, coalesce(a.usage_qty,0) as analytics_usage_qty
	, coalesce(o.operators,0) as operators_qty
	, 'base_metrics' as row_type
from base_table b
left join bi_daily_ltv lt on lt.brand_id = b.brand_id and lt.dt = b.dt
left join revenue r on r.brand_id = b.brand_id and r.dt = b.dt
left join sendings_total s on s.brand_id = b.brand_id and s.dt = b.dt
left join analytics a on a.brand_id = b.brand_id and a.dt = b.dt
left join operators_agg o on o.brand_id = b.brand_id and o.dt = b.dt
left join brands_w_clients c on c.brand_id = b.brand_id and c.dt = b.dt)
select
	  coalesce(t.brand_id, o.brand_id) as brand_id
	, coalesce(t.brand_name, o.brand_name) as brand_name
	, coalesce(t.accountManager, o.accountManager) as accountManager
	, coalesce(t.dt, o.dt) as dt
	, coalesce(t.status_name, o.status_name) as status_name
	, t.daily_fee as daily_fee
	, t.LT as LT
	, t.clients as clients
	, t.revenue as revenue
	, t.pl_revenue as pl_revenue
	, t.orders as orders
	, t.pl_orders as pl_orders
	, t.sendings_qty as sendings_qty
	, t.analytics_usage_qty as analytics_usage_qty
	, t.operators_qty as operators_qty
	, o.offer_synth_id as offer_synth_id
	, o.dt_offer_start as dt_offer_start
	, coalesce(t.row_type, 'offers') as row_type
from total t
full join offer_final o on false;

select * from bi_brands_criticality;

------
--BI-96 Дашборд для ежегодных исследований
------
--Промежуточная таблица по покупкам
drop table bi_brands_research_purchase;	  
create live view bi_brands_research_purchase with refresh 14400 as
with purch as
(select
	  date(date_trunc('month', p.createdAt, 'Europe/Moscow')) as mon
	, p.globalKey
	, p.id
	, p.clientId
	, p.bonusesApplied
	, p.offerDiscount
	, pc.codeType
	, p.paidAmount
from purchase p
left join promocode pc on pc.globalKey = p.globalKey and pc.id = p.promocodeId
where date(p.createdAt, 'Europe/Moscow') >= '2023-07-01' and p.createdAt <= now())
select
	  p.mon as mon
	, p.globalKey as brand_id
	, 'purchase_data' as row_type
	, max(case when p.bonusesApplied > 0 then 1 else 0 end) as bonuses_lp
	, max(case when p.offerDiscount > 0 or po.amount > 0 then 1 else 0 end) as offer_lp
	, count(p.id) as total_purchases
	, sum(coalesce(p.paidAmount,0)) as revenue
	, count(p.clientId) as pl_purchases
	, count(case when p.codeType = 0 then p.id end) as common_promocodes
	, count(case when p.codeType > 0 then p.id end) as personal_promocodes
from purch p
left join purchase_offer po on po.purchaseId = p.id and po.globalKey = p.globalKey
group by 1,2,3;

select * from bi_brands_research_purchase;

drop table bi_brands_research;	  
create live view bi_brands_research with refresh 14400 as
with mons as
(select distinct mon from bi_brands_research_purchase),
levels as
(select
	  globalKey as brand_id
	, count(*) as levels_qty
	, min(case when cashbackFactor > 0 then cashbackFactor end) as min_cashback
	, max(case when cashbackFactor > 0 then cashbackFactor end) as max_cashback
	, min(case when cashbackFactor > 0 then totalSpent end) as min_spent_level
	, max(case when cashbackFactor > 0 then totalSpent end) as max_spent_level
from level
group by 1), 
ind_rev_data as
(select
	  brand_id
	, rev_type
	, arrayStringConcat(groupUniqArray(industry),', ') as industry
	, arrayStringConcat(groupUniqArray(soft),', ') as soft
from bi_product_target_group
group by 1,2),
clients_data as
(select
	  brand_id
	, max(clients) as clients
from bi_daily_brand_clients
group by 1),
brand_data as
(select
	  coalesce(l.brand_id, i.brand_id, c.brand_id) as brand_id
	, l.levels_qty as levels_qty
	, l.min_cashback as min_cashback
	, l.max_cashback as max_cashback
	, l.min_spent_level as min_spent_level
	, l.max_spent_level as max_spent_level
	, coalesce(i.rev_type, '-') as rev_type
	, coalesce(case when i.industry = '' then null else i.industry end, '-') as industry
	, coalesce(case when i.soft = '' then null else i.soft end, '-') as soft
	, case 
		when c.clients < 5000 then 'до 4 999'
		when c.clients < 10000 then '5 000 - 9 999'
		when c.clients < 25000 then '10 000 - 24 999'
		when c.clients < 50000 then '25 000 - 49 999'
		when c.clients >= 50000 then 'более 50 000'
	  else '-' end as clients_segment
from levels l
full join ind_rev_data i on i.brand_id = l.brand_id
full join clients_data c on c.brand_id = coalesce(l.brand_id, i.brand_id)),
brand_data_w_mon as
(select 
	  m.mon as mon
	, b.brand_id as brand_id
	, b.levels_qty as levels_qty
	, b.min_cashback as min_cashback
	, b.max_cashback as max_cashback
	, b.min_spent_level as min_spent_level
	, b.max_spent_level as max_spent_level
	, b.rev_type as rev_type
	, b.industry as industry
	, b.soft as soft
	, b.clients_segment as clients_segment
from brand_data b, mons m),
sendings as
(select 
	  date(date_trunc('month', dtime)) as mon
	, brand_id
	, 'sendings_data' as row_type
	, name
	, channels
	, case
		when trigger_type <> 'Без триггера' then 'trigger'
		when recipients = 'Все сегменты' then 'mass'
		else 'personal'
	  end as sending_type
	, sum(sended) as sended
	, sum(delivered) as delivered
	, sum(opened) as opened
	, sum(orders) as orders
from bi_mechanics_sendings
where date(dtime) >= '2023-01-01' and dtime <= now()
group by 1,2,3,4,5,6),
modules as
(select
	  date(date_trunc('month', dt)) as mon
	, brand_id
	, max(case when tariff_module_name = 'Карты Wallet' and tariff_fee > 0 then 1 else 0 end) as wallet
	, max(case when tariff_module_name = 'Telegram-бот' and tariff_fee > 0 then 1 else 0 end) as tg_bot
	, max(case when tariff_module_name = 'SmartRFM' and tariff_fee > 0 then 1 else 0 end) as rfm
from bi_daily_tariff_module
where dt >= '2023-01-01'
group by 1,2)
select
	  coalesce(p.mon, s.mon) as mon
	, coalesce(p.brand_id, s.brand_id) as brand_id
	, br.name as brand_name
	, coalesce(p.row_type, s.row_type) as row_type
	, p.bonuses_lp as bonuses_lp
	, p.offer_lp as offer_lp
	, p.total_purchases as total_purchases
	, p.revenue as revenue
	, p.pl_purchases as pl_purchases
	, p.common_promocodes as common_promocodes
	, p.personal_promocodes as personal_promocodes
	, b.levels_qty as levels_qty
	, b.min_cashback as min_cashback
	, b.max_cashback as max_cashback
	, b.min_spent_level as min_spent_level
	, b.max_spent_level as max_spent_level
	, b.rev_type as rev_type
	, b.industry as industry
	, ig.industry_group as industry_group
	, b.soft as soft
	, b.clients_segment as clients_segment
	, m.wallet as wallet
	, m.tg_bot as tg_bot
	, m.rfm as rfm
	, s.name as sending_name
	, s.channels as channels
	, s.sending_type as sending_type
	, s.sended as sended
	, s.delivered as delivered
	, s.opened as opened
	, s.orders as orders
	, case when s.delivered  >= s.sended then 1.0 else 1.0 * s.delivered / nullif(s.sended, 0) end as dr
	, case when channels like '%E-Mail%' then case when s.opened  >= s.delivered then 1.0 else 1.0 * s.opened / nullif(s.delivered, 0) end end as or
	, case when channels like '%E-Mail%' then case when s.orders  >= s.opened then 1.0 else 1.0 * s.orders / nullif(s.opened, 0) end end as sor
	, case when s.orders  >= s.delivered then 1.0 else 1.0 * s.orders / nullif(s.delivered, 0) end as sdr
from bi_brands_research_purchase p
full join sendings s on false
left join modules m on m.brand_id = p.brand_id and m.mon = p.mon
left join brand_data_w_mon b on b.brand_id = coalesce(p.brand_id, s.brand_id) and b.mon = coalesce(p.mon, s.mon)
left join brand br on br.globalKey = coalesce(p.brand_id, s.brand_id)
left join bi_industry_group ig on ig.industry = b.industry;

--Квартили по числу клиентов
with brand_clients_data as
(select
	  brand_id
	, max(clients) as clients
from bi_daily_brand_clients
group by 1)
select
	  quantile(0.2)(clients) as q1
	, quantile(0.4)(clients) as q2
	, quantile(0.6)(clients) as q3
	, quantile(0.8)(clients) as q4
from t
where clients > 1000;
--q1 0 - 5000
--q2 5000 - 10000
--q3 10000 - 25000
--q4 25000 - 50000
--q5 50000 - ...

select * from bi_brands_research;
