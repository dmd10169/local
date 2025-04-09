---------------
alter table brand_settings_history 
modify comment 'Данные по истории настроек брендов';
---------------

---------------
alter table brand 
modify comment 'Данные по брендам';
---------------

---------------
alter table brand_status_history 
modify comment 'Исторические данные по статусам брендов';
---------------

---------------
alter table bi_brand_managers 
modify comment 'Менеджеры и бренды по дням с историей изменений';

alter table bi_brand_managers 
modify column brand_id 
comment 'ID бренда';

alter table bi_brand_managers 
modify column dt 
comment 'День';

alter table bi_brand_managers 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_brand_managers 
modify column salesManager 
comment 'Менеджер продаж';

alter table bi_brand_managers 
modify column projectManager 
comment 'Менеджер запуска';
---------------

---------------
alter table bi_brand_status 
modify comment 'Бренды с историей статусов';

alter table bi_brand_status 
modify column brand_id 
comment 'ID бренда';

alter table bi_brand_status 
modify column dt_from 
comment 'Дата начала статуса';

alter table bi_brand_status 
modify column dt_to 
comment 'Дата окончания статуса';

alter table bi_brand_status 
modify column status 
comment 'ID статуса';
---------------

---------------
alter table bi_daily_fee 
modify comment 'Данные по списанию абонентской платы в разрезе менеджеров и брендов';

alter table bi_daily_fee 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_fee 
modify column dt 
comment 'День';

alter table bi_daily_fee 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_fee 
modify column salesManager 
comment 'Менеджер продаж';

alter table bi_daily_fee 
modify column projectManager 
comment 'Менеджер запуска';

alter table bi_daily_fee 
modify column fee
comment 'Ежемесячная абонка';

alter table bi_daily_fee 
modify column daily_fee
comment 'Ежедневное списание абонки';

alter table bi_daily_fee 
modify column deposit
comment 'Депозит';

alter table bi_daily_fee 
modify column balance
comment 'Текущий баланс на день';

alter table bi_daily_fee 
modify column status
comment 'ID статуса';
---------------

---------------
alter table bi_daily_revenue 
modify comment 'Аналог bi_daily_fee содержащий данные чисто по выручке';

alter table bi_daily_revenue 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_revenue 
modify column dt 
comment 'День';

alter table bi_daily_revenue 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_revenue 
modify column revenue
comment 'Дневная выручка (= дневное списание абонки)';

alter table bi_daily_revenue 
modify column status
comment 'ID статуса';
---------------

---------------
alter table bi_daily_starts 
modify comment 'Данные по запускам брендов по дням';

alter table bi_daily_starts 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_starts 
modify column dt 
comment 'День';

alter table bi_daily_starts 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_starts 
modify column fee_start
comment 'Ежемесячная абонка при запуске бренда';

alter table bi_daily_starts 
modify column fee_start_date
comment 'Дата запуска бренда';

alter table bi_daily_starts 
modify column status
comment 'ID статуса';
---------------

---------------
alter table bi_daily_fee_dynamic 
modify comment 'Данные по изменения абонентской платы брендов по дням';

alter table bi_daily_fee_dynamic 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_fee_dynamic 
modify column dt 
comment 'День';

alter table bi_daily_fee_dynamic 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_fee_dynamic 
modify column fee
comment 'Ежемесячная абонка';

alter table bi_daily_fee_dynamic 
modify column fee_delta_all
comment 'Дневное изменение абонки';

alter table bi_daily_fee_dynamic 
modify column fee_delta
comment 'Дневное изменение абонки, исключая запуски';

alter table bi_daily_fee_dynamic 
modify column fee_up
comment 'Положительное дневное изменение абонки, исключая запуски';

alter table bi_daily_fee_dynamic 
modify column fee_down
comment 'Отрицательное дневное изменение абонки, исключая запуски';

alter table bi_daily_fee_dynamic 
modify column fee_up_rollup
comment 'Положительные изменения абонки за месяц (сумма всех изменений в течение месяца, атрибуцированная к дате наибольшего роста абонки)';

alter table bi_daily_fee_dynamic 
modify column fee_down_rollup
comment 'Отрицательные изменения абонки за месяц (сумма всех изменений в течение месяца, атрибуцированная к дате наибольшего падения абонки)';
---------------

---------------
alter table bi_daily_ltv 
modify comment 'Расчёт LTV и LT брендов по дням';

alter table bi_daily_ltv 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_ltv 
modify column dt 
comment 'День';

alter table bi_daily_ltv 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_ltv 
modify column salesManager 
comment 'Менеджер продаж';

alter table bi_daily_ltv 
modify column status
comment 'ID статуса';

alter table bi_daily_ltv 
modify column LTV_on_date
comment 'Накопительная выручка бренда на день';

alter table bi_daily_ltv 
modify column LT_on_date
comment 'Накопительный срок жизни бренда на день (учитываем дни с выручкой)';

alter table bi_daily_ltv 
modify column LT
comment 'Базовое значение LT для расчёта прогноза LTV (по индустриям)';

alter table bi_daily_ltv 
modify column LTV
comment 'Прогнозный расчёт LTV бренда  (по индустриям)';

alter table bi_daily_ltv 
modify column LT_account_manager
comment 'Базовое значение LT для расчёта прогноза LTV (по акк. маркетологам)';

alter table bi_daily_ltv 
modify column LT_sales_manager
comment 'Базовое значение LT для расчёта прогноза LTV (по менеджерам продаж)';
---------------

---------------
alter table bi_daily_aov 
modify comment 'Аналог bi_daily_fee содержащий данные чисто по выручке';

alter table bi_daily_aov 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_aov 
modify column dt 
comment 'День';

alter table bi_daily_aov 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_aov 
modify column AOV
comment 'Средний чек бренда (= сумма ежемесячной абонки)';
---------------

---------------
alter table bi_daily_v_start 
modify comment 'Данные по сроку запуска брендов';

alter table bi_daily_v_start 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_v_start 
modify column af 
comment 'Номер запуска (в случаях, если бренд ушёл в архив и его потом перезапустили, это поле поможет посчитать все запуски бренда)';

alter table bi_daily_v_start 
modify column dt 
comment 'День';

alter table bi_daily_v_start 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_v_start 
modify column v_start_days
comment 'Срок запуска бренда в днях (без учёта новогодних праздников)';
---------------

---------------
alter table bi_daily_sla_v_start 
modify comment 'Данные для расчёта SLA запусков';

alter table bi_daily_sla_v_start 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_sla_v_start 
modify column brand_name 
comment 'Наименование бренда';

alter table bi_daily_sla_v_start 
modify column dt 
comment 'День';

alter table bi_daily_sla_v_start 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_sla_v_start 
modify column status
comment 'ID статуса';

alter table bi_daily_sla_v_start 
modify column status_name
comment 'Наименование статуса';

alter table bi_daily_sla_v_start 
modify column fee_start
comment 'Ежемесячная абонка при запуске бренда';

alter table bi_daily_sla_v_start 
modify column fee_start_date
comment 'Дата запуска бренда';

alter table bi_daily_sla_v_start 
modify column start_flag
comment 'Флаг дня со стартом бренда';

alter table bi_daily_sla_v_start 
modify column v_start_days
comment 'Срок запуска бренда в днях';
---------------

---------------
alter table bi_daily_brand_clients 
modify comment 'Данные по числу клиентов бренда с расчётом абонки (если нет тарифов) и оценка прогноза по кол-ву клиентов и абонке';

alter table bi_daily_brand_clients 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_brand_clients 
modify column dt 
comment 'День';

alter table bi_daily_brand_clients 
modify column clients 
comment 'Число клиентов на дату';

alter table bi_daily_brand_clients 
modify column clients_min
comment 'Минимальная граница числа клиентов в текущем пороге (считается, если нет тарифов)';

alter table bi_daily_brand_clients 
modify column clients_max
comment 'Максимальная граница числа клиентов в текущем пороге (считается, если нет тарифов)';

alter table bi_daily_brand_clients 
modify column fee_value
comment 'Расчётная ежемесячная абонка';

alter table bi_daily_brand_clients 
modify column clients_forecast
comment 'Прогнозное число клиентов до запуска бренда';

alter table bi_daily_brand_clients 
modify column fee_value_forecast
comment 'Прогнозная ежемесячна абонка исходя из прогнозного числа клиентов';
---------------

---------------
alter table client 
modify comment 'Данные по клиентам брендов';
---------------

---------------
alter table brand_price_history 
modify comment 'Исторические данные по ценам брендов';
---------------

---------------
alter table expense 
modify comment 'Данные по списаниям с баланса брендов';
---------------

---------------
alter table deposit 
modify comment 'Данные по депозитам брендов';
---------------

---------------
alter table bi_brand_pilot_dates 
modify comment 'Даты пилота для каждого бренда';

alter table bi_brand_pilot_dates 
modify column brand_id 
comment 'ID бренда';

alter table bi_brand_pilot_dates 
modify column pilotFrom 
comment 'Дата старта пилота';

alter table bi_brand_pilot_dates 
modify column pilotFrom 
comment 'Дата окончания пилота';
---------------

---------------
alter table bi_daily_clients 
modify comment 'Данные по статусам и событиям статусов брендов по дням';

alter table bi_daily_clients 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_clients 
modify column dt 
comment 'День';

alter table bi_daily_clients 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_clients 
modify column integration 
comment 'Бренд на статусе "На интеграции"';

alter table bi_daily_clients 
modify column integration_active
comment 'Бренд на статусе "Подготовка к запуску"';

alter table bi_daily_clients 
modify column pilot
comment 'Бренд в пилоте';

alter table bi_daily_clients 
modify column stopped
comment 'Бренд на статусе "Приостановлен"';

alter table bi_daily_clients 
modify column lost
comment 'Бренд на статусах "Архивный" и "Удалён"';

alter table bi_daily_clients 
modify column total
comment 'Бренд на статусе "Активен"';

alter table bi_daily_clients 
modify column integration_flag
comment 'Флаг первой даты перехода на статус "На интеграции"';

alter table bi_daily_clients 
modify column integration_active_flag
comment 'Флаг первой даты перехода на статус "Подготовка к запуску"';

alter table bi_daily_clients 
modify column pilot_flag
comment 'Флаг старта пилота';

alter table bi_daily_clients 
modify column stopped_flag
comment 'Флаг первой даты перехода на статус "Приостановлен"';

alter table bi_daily_clients 
modify column lost_flag
comment 'Флаг первой даты перехода на статусы "Архивный" или "Удалён"';
---------------

---------------
alter table bi_daily_fee_type_dynamic 
modify comment 'Данные по событиям изменений абонки по брендам и дням';

alter table bi_daily_fee_type_dynamic 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_fee_type_dynamic 
modify column dt 
comment 'День';

alter table bi_daily_fee_type_dynamic 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_fee_type_dynamic 
modify column salesManager 
comment 'Менеджер продаж';

alter table bi_daily_fee_type_dynamic 
modify column projectManager 
comment 'Менеджер запуска';

alter table bi_daily_fee_type_dynamic 
modify column delta_type
comment 'Тип события изменения абонки';

alter table bi_daily_fee_type_dynamic 
modify column delta_type_up
comment 'Тип события положительного изменения абонки';

alter table bi_daily_fee_type_dynamic 
modify column delta_type_down
comment 'Тип события отрицательного изменения абонки';

alter table bi_daily_fee_type_dynamic 
modify column fee_delta
comment 'Изменение абонки';
---------------

---------------
alter table bi_daily_tariff_module 
modify comment 'Данные по тарифу и модулям внутри него в разрезе дней и брендов';

alter table bi_daily_tariff_module 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_tariff_module 
modify column dt 
comment 'День';

alter table bi_daily_tariff_module 
modify column tariff_name 
comment 'Название тарифа';

alter table bi_daily_tariff_module 
modify column tariff_module_name 
comment 'Название модуля внутри тарифа';

alter table bi_daily_tariff_module 
modify column clientsTo
comment 'Верхняя граница клиентов для текущего действующего модуля тарифа';

alter table bi_daily_tariff_module 
modify column pricePerClient
comment 'Дополнительная цена за одного клиента выше границы clientsTo (если граница максимальна и число клиентов более clientsTo)';

alter table bi_daily_tariff_module 
modify column pricePerClient_next
comment 'Дополнительная цена за одного клиента выше границы clientsTo (если граница максимальна и число клиентов менее clientsTo)';

alter table bi_daily_tariff_module 
modify column discount_value
comment 'Размер скидки';

alter table bi_daily_tariff_module 
modify column tariff_fee
comment 'Стоимость ежемесячной абонки по модулю тарифа';

alter table bi_daily_tariff_module 
modify column tariff_fee_next
comment 'Стоимость ежемесячной абонки по модулю тарифа на следующей ступеньке (после преодоления порога clientsTo)';
---------------

---------------
alter table bi_daily_debt 
modify comment 'Данные по долгам брендов по дням';

alter table bi_daily_debt 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_debt 
modify column dt 
comment 'День';

alter table bi_daily_debt 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_debt 
modify column debt 
comment 'Сумма задолженности';

alter table bi_daily_debt 
modify column fee 
comment 'Ежемесячная абонка при активном статусе';
---------------

---------------
alter table bi_daily_active_man_flag 
modify comment 'Учёт активных аккаунт-маркетологов по дням';

alter table bi_daily_active_man_flag 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_active_man_flag 
modify column dt 
comment 'День';

alter table bi_daily_active_man_flag 
modify column fee 
comment 'Ежемесячная абонка';

alter table bi_daily_active_man_flag 
modify column active_flag 
comment 'Флаг активного аккаунт-маркетолога (абонка больше нуля)';
---------------

---------------
alter table bi_daily_brand_data 
modify comment 'Сводные данные по всем метрикам брендов по дням';

alter table bi_daily_brand_data 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_brand_data 
modify column dt 
comment 'День';

alter table bi_daily_brand_data 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_daily_brand_data 
modify column archiveReason 
comment 'Причина отключения бренда (переноса в архив)';

alter table bi_daily_brand_data 
modify column active_flag 
comment 'Флаг активного аккаунт-маркетолога (абонка больше нуля)';

alter table bi_daily_brand_data 
modify column status
comment 'ID статуса';

alter table bi_daily_brand_data 
modify column monthly_fee
comment 'Ежемесячная абонка';

alter table bi_daily_brand_data 
modify column fee_delta_all
comment 'Дневное изменение абонки';

alter table bi_daily_brand_data 
modify column fee_delta
comment 'Дневное изменение абонки, исключая запуски';

alter table bi_daily_brand_data 
modify column fee_up
comment 'Положительное дневное изменение абонки, исключая запуски';

alter table bi_daily_brand_data 
modify column fee_down
comment 'Отрицательное дневное изменение абонки, исключая запуски';

alter table bi_daily_brand_data 
modify column LTV_on_date
comment 'Накопительная выручка бренда на день';

alter table bi_daily_brand_data 
modify column LT_on_date
comment 'Накопительный срок жизни бренда на день (учитываем дни с выручкой)';

alter table bi_daily_brand_data 
modify column LT
comment 'Базовое значение LT для расчёта прогноза LTV (по индустриям)';

alter table bi_daily_brand_data 
modify column LTV
comment 'Прогнозный расчёт LTV бренда (по индустриям)';

alter table bi_daily_brand_data 
modify column LT_account_manager
comment 'Базовое значение LT для расчёта прогноза LTV (по акк. маркетологам)';

alter table bi_daily_brand_data 
modify column LT_sales_manager
comment 'Базовое значение LT для расчёта прогноза LTV (по менеджерам продаж)';

alter table bi_daily_brand_data 
modify column AOV
comment 'Средний чек бренда (= сумма ежемесячной абонки)';

alter table bi_daily_brand_data 
modify column debt 
comment 'Сумма задолженности';

alter table bi_daily_brand_data 
modify column fee_for_debt 
comment 'Ежемесячная абонка при активном статусе';

alter table bi_daily_brand_data 
modify column integration 
comment 'Бренд на статусе "На интеграции"';

alter table bi_daily_brand_data 
modify column integration_active
comment 'Бренд на статусе "Подготовка к запуску"';

alter table bi_daily_brand_data 
modify column pilot
comment 'Бренд в пилоте';

alter table bi_daily_brand_data 
modify column stopped
comment 'Бренд на статусе "Приостановлен"';

alter table bi_daily_brand_data 
modify column lost
comment 'Бренд на статусах "Архивный" и "Удалён"';

alter table bi_daily_brand_data 
modify column total
comment 'Бренд на статусе "Активен"';

alter table bi_daily_brand_data 
modify column fee_start_date
comment 'Дата запуска бренда';

alter table bi_daily_brand_data 
modify column active_manager
comment 'Флаг активного аккаунт-маркетолога (не удалён из CRM)';
---------------

---------------
alter table bi_houry_brand_data 
modify comment 'Почасовые данные по изменениям статусов брендов';

alter table bi_houry_brand_data 
modify column brand_id 
comment 'ID бренда';

alter table bi_houry_brand_data 
modify column dtime 
comment 'Дата и время';

alter table bi_houry_brand_data 
modify column status_chg 
comment 'ID статуса при изменении';

alter table bi_houry_brand_data 
modify column max_dtime_starts
comment 'Максимальная дата и время перевода на активный статус';

alter table bi_houry_brand_data 
modify column max_dtime_toint
comment 'Максимальная дата и время перевода на статусы интеграции';

alter table bi_houry_brand_data 
modify column max_dtime_losts
comment 'Максимальная дата и время перевода в архив или удаления бренда';

alter table bi_houry_brand_data 
modify column max_dtime_stops
comment 'Максимальная дата и время перевода на статус приостановки';
---------------

---------------
alter table bi_chronology_status_w_fee 
modify comment 'События по статусам с изменением абонки по брендам и часам';

alter table bi_chronology_status_w_fee 
modify column brand_id 
comment 'ID бренда';

alter table bi_chronology_status_w_fee 
modify column dtime 
comment 'Дата и время';

alter table bi_chronology_status_w_fee 
modify column action_type 
comment 'Тип события';

alter table bi_chronology_status_w_fee 
modify column fee_delta 
comment 'Изменение абонки';
---------------

---------------
alter table bi_chronology_status_wo_fee 
modify comment 'События по статусам без изменения абонки по брендам и часам';

alter table bi_chronology_status_wo_fee 
modify column brand_id 
comment 'ID бренда';

alter table bi_chronology_status_wo_fee 
modify column dtime 
comment 'Дата и время';

alter table bi_chronology_status_wo_fee 
modify column action_type 
comment 'Тип события';

alter table bi_chronology_status_wo_fee 
modify column fee_delta 
comment 'Изменение абонки';
---------------

---------------
alter table bi_chronology_moduls 
modify comment 'События по модулям (до включения в тарифы) по брендам и часам';

alter table bi_chronology_moduls 
modify column brand_id 
comment 'ID бренда';

alter table bi_chronology_moduls 
modify column dtime 
comment 'Дата и время';

alter table bi_chronology_moduls 
modify column action_type 
comment 'Тип события';

alter table bi_chronology_moduls 
modify column fee_delta 
comment 'Изменение абонки';
---------------

---------------
alter table bi_chronology_hand_corr 
modify comment 'События по ручным корректировкам (без тарифов) по брендам и часам';

alter table bi_chronology_hand_corr 
modify column brand_id 
comment 'ID бренда';

alter table bi_chronology_hand_corr 
modify column dtime 
comment 'Дата и время';

alter table bi_chronology_hand_corr 
modify column action_type 
comment 'Тип события';

alter table bi_chronology_hand_corr 
modify column fee_delta 
comment 'Изменение абонки';
---------------

---------------
alter table bi_chronology_pilot_stop 
modify comment 'События по изменению абонки после окончания пилота по брендам и часам';

alter table bi_chronology_pilot_stop 
modify column brand_id 
comment 'ID бренда';

alter table bi_chronology_pilot_stop 
modify column dtime 
comment 'Дата и время';

alter table bi_chronology_pilot_stop 
modify column action_type 
comment 'Тип события';

alter table bi_chronology_pilot_stop 
modify column fee_delta 
comment 'Изменение абонки';
---------------

---------------
alter table bi_chronology_tariffs 
modify comment 'События по изменению внутри тарифов (с модулями) по брендам и часам';

alter table bi_chronology_tariffs 
modify column brand_id 
comment 'ID бренда';

alter table bi_chronology_tariffs 
modify column dtime 
comment 'Дата и время';

alter table bi_chronology_tariffs 
modify column action_type 
comment 'Тип события';

alter table bi_chronology_tariffs 
modify column fee_delta 
comment 'Изменение абонки';
---------------

---------------
alter table bi_chronology_clients 
modify comment 'События по изменению клиентской базы (до использования тарифов) по брендам и часам';

alter table bi_chronology_clients 
modify column brand_id 
comment 'ID бренда';

alter table bi_chronology_clients 
modify column dtime 
comment 'Дата и время';

alter table bi_chronology_clients 
modify column action_type 
comment 'Тип события';

alter table bi_chronology_clients 
modify column fee_delta 
comment 'Изменение абонки';
---------------

---------------
alter table bi_product_target_group 
modify comment 'Анализ целевой аудитории брендов';

alter table bi_product_target_group 
modify column brand_id 
comment 'ID бренда';

alter table bi_product_target_group 
modify column name 
comment 'Наименование бренда';

alter table bi_product_target_group 
modify column industry 
comment 'Индустрия бренда';

alter table bi_product_target_group 
modify column soft 
comment 'Софт бренда';

alter table bi_product_target_group 
modify column rev_type 
comment 'Категория бренда по выручке';

alter table bi_product_target_group 
modify column aov_type 
comment 'Категория бренда по среднему чеку';

alter table bi_product_target_group 
modify column shops_qty 
comment 'Число торговых точек бренда';

alter table bi_product_target_group 
modify column dt 
comment 'День';

alter table bi_product_target_group 
modify column status
comment 'ID статуса';

alter table bi_product_target_group 
modify column fee
comment 'Ежемесячная абонка';

alter table bi_product_target_group 
modify column daily_fee
comment 'Ежедневное списание абонки';

alter table bi_product_target_group 
modify column fee_up
comment 'Положительное дневное изменение абонки, исключая запуски';

alter table bi_product_target_group 
modify column fee_down
comment 'Отрицательное дневное изменение абонки, исключая запуски';

alter table bi_product_target_group 
modify column LTV_on_date
comment 'Накопительная выручка бренда на день';

alter table bi_product_target_group 
modify column LTV
comment 'Прогнозный расчёт LTV бренда  (по индустриям)';

alter table bi_product_target_group 
modify column start_days
comment 'Срок запуска бренда в днях (без учёта новогодних праздников)';

alter table bi_product_target_group 
modify column gain_sum
comment 'Выручка бренда';

alter table bi_product_target_group 
modify column lost_sum
comment 'Затраты бренда (на акции и скидки и на оплату MAXMA)';

alter table bi_product_target_group 
modify column orders_qty
comment 'Число чеков бренда';
---------------

---------------
alter table bi_mechanics_sendings 
modify comment 'Модуль с данными по рассылкам';

alter table bi_mechanics_sendings 
modify column module_type 
comment 'Тип модуля';

alter table bi_mechanics_sendings 
modify column brand_id 
comment 'ID бренда';

alter table bi_mechanics_sendings 
modify column dtime 
comment 'Дата и время';

alter table bi_mechanics_sendings 
modify column last_sale_dt 
comment 'Дата и время последней продажи бренда';

alter table bi_mechanics_sendings 
modify column trigger_type 
comment 'Тип триггера рассылки';

alter table bi_mechanics_sendings 
modify column name 
comment 'Наименование рассылки';

alter table bi_mechanics_sendings 
modify column offer_type 
comment 'Тип акции';

alter table bi_mechanics_sendings 
modify column offer_type 
comment 'Бонусный размер акции';

alter table bi_mechanics_sendings 
modify column recipients 
comment 'Получатели рассылки';

alter table bi_mechanics_sendings 
modify column sended 
comment 'Число отправлений';

alter table bi_mechanics_sendings 
modify column delivered 
comment 'Число доставок';

alter table bi_mechanics_sendings 
modify column opened 
comment 'Число открытых рассылок';

alter table bi_mechanics_sendings 
modify column unsubscribed 
comment 'Число отписок';

alter table bi_mechanics_sendings 
modify column channels 
comment 'Каналы рассылок';

alter table bi_mechanics_sendings 
modify column sms_body 
comment 'Текст рассылки в SMS';

alter table bi_mechanics_sendings 
modify column push_body 
comment 'Текст рассылки в Push рассылке';

alter table bi_mechanics_sendings 
modify column viber_body 
comment 'Текст рассылки в рассылке по Viber';

alter table bi_mechanics_sendings 
modify column email_url 
comment 'Превью e-mail рассылки';

alter table bi_mechanics_sendings 
modify column orders 
comment 'Число чеков бренда';

alter table bi_mechanics_sendings 
modify column revenue 
comment 'Выручка бренда';

alter table bi_mechanics_sendings 
modify column disc_lost 
comment 'Затраты на скидки бренда';

alter table bi_mechanics_sendings 
modify column maxma_lost 
comment 'Затраты бренда на MAXMA';
---------------

---------------
alter table bi_mechanics_tools_promo 
modify comment 'Модуль с данными по акциям';

alter table bi_mechanics_tools_promo 
modify column module_type 
comment 'Тип модуля';

alter table bi_mechanics_tools_promo 
modify column brand_id 
comment 'ID бренда';

alter table bi_mechanics_tools_promo 
modify column dtime 
comment 'Дата и время';

alter table bi_mechanics_tools_promo 
modify column last_sale_dt 
comment 'Дата и время последней продажи бренда';

alter table bi_mechanics_tools_promo 
modify column trigger_type 
comment 'Поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column name 
comment 'Наименование акции';

alter table bi_mechanics_tools_promo 
modify column offer_type 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column offer_type 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column recipients 
comment 'Получатели акции';

alter table bi_mechanics_tools_promo 
modify column sended 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column delivered 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column opened 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column unsubscribed 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column channels 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column sms_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column push_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column viber_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column email_url 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promo 
modify column orders 
comment 'Число чеков бренда';

alter table bi_mechanics_tools_promo 
modify column revenue 
comment 'Выручка бренда';

alter table bi_mechanics_tools_promo 
modify column disc_lost 
comment 'Затраты на скидки бренда';

alter table bi_mechanics_tools_promo 
modify column maxma_lost 
comment 'Затраты бренда на MAXMA';
---------------

---------------
alter table bi_mechanics_tools_promocodes 
modify comment 'Модуль с данными по промокодам';

alter table bi_mechanics_tools_promocodes 
modify column module_type 
comment 'Тип модуля';

alter table bi_mechanics_tools_promocodes 
modify column brand_id 
comment 'ID бренда';

alter table bi_mechanics_tools_promocodes 
modify column dtime 
comment 'Дата и время';

alter table bi_mechanics_tools_promocodes 
modify column last_sale_dt 
comment 'Дата и время последней продажи бренда';

alter table bi_mechanics_tools_promocodes 
modify column trigger_type 
comment 'Поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column name 
comment 'Наименование промокода';

alter table bi_mechanics_tools_promocodes 
modify column offer_type 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column offer_type 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column recipients 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column sended 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column delivered 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column opened 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column unsubscribed 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column channels 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column sms_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column push_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column viber_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column email_url 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_promocodes 
modify column orders 
comment 'Число чеков бренда';

alter table bi_mechanics_tools_promocodes 
modify column revenue 
comment 'Выручка бренда';

alter table bi_mechanics_tools_promocodes 
modify column disc_lost 
comment 'Затраты на скидки бренда';

alter table bi_mechanics_tools_promocodes 
modify column maxma_lost 
comment 'Затраты бренда на MAXMA';
---------------

---------------
alter table bi_mechanics_tools_friend 
modify comment 'Модуль с данными по промокодам Приведи друга';

alter table bi_mechanics_tools_friend 
modify column module_type 
comment 'Тип модуля';

alter table bi_mechanics_tools_friend 
modify column brand_id 
comment 'ID бренда';

alter table bi_mechanics_tools_friend 
modify column dtime 
comment 'Дата и время';

alter table bi_mechanics_tools_friend 
modify column last_sale_dt 
comment 'Дата и время последней продажи бренда';

alter table bi_mechanics_tools_friend 
modify column trigger_type 
comment 'Поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column name 
comment 'Наименование промокода';

alter table bi_mechanics_tools_friend 
modify column offer_type 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column offer_type 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column recipients 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column sended 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column delivered 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column opened 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column unsubscribed 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column channels 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column sms_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column push_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column viber_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column email_url 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_friend 
modify column orders 
comment 'Число чеков бренда';

alter table bi_mechanics_tools_friend 
modify column revenue 
comment 'Выручка бренда';

alter table bi_mechanics_tools_friend 
modify column disc_lost 
comment 'Затраты на скидки бренда';

alter table bi_mechanics_tools_friend 
modify column maxma_lost 
comment 'Затраты бренда на MAXMA';
---------------

---------------
alter table bi_mechanics_tools_giftcard 
modify comment 'Модуль с данными по подарочным картам';

alter table bi_mechanics_tools_giftcard 
modify column module_type 
comment 'Тип модуля';

alter table bi_mechanics_tools_giftcard 
modify column brand_id 
comment 'ID бренда';

alter table bi_mechanics_tools_giftcard 
modify column dtime 
comment 'Дата и время';

alter table bi_mechanics_tools_giftcard 
modify column last_sale_dt 
comment 'Дата и время последней продажи бренда';

alter table bi_mechanics_tools_giftcard 
modify column trigger_type 
comment 'Поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column name 
comment 'Наименование карты';

alter table bi_mechanics_tools_giftcard 
modify column offer_type 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column offer_type 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column recipients 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column sended 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column delivered 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column opened 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column unsubscribed 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column channels 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column sms_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column push_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column viber_body 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column email_url 
comment 'Пустое поле для объединения модулей';

alter table bi_mechanics_tools_giftcard 
modify column orders 
comment 'Число чеков бренда';

alter table bi_mechanics_tools_giftcard 
modify column revenue 
comment 'Выручка бренда';

alter table bi_mechanics_tools_giftcard 
modify column disc_lost 
comment 'Затраты на скидки бренда';

alter table bi_mechanics_tools_giftcard 
modify column maxma_lost 
comment 'Затраты бренда на MAXMA';
---------------

---------------
alter table bi_sendings_services 
modify comment 'Данные по сервисам рассылок';

alter table bi_sendings_services 
modify column brand_id 
comment 'ID бренда';

alter table bi_sendings_services 
modify column brand_name 
comment 'Наименование бренда';

alter table bi_sendings_services 
modify column status
comment 'Наименование статуса';

alter table bi_sendings_services 
modify column inn
comment 'ИНН бренда';

alter table bi_sendings_services 
modify column accountManager
comment 'Аккаунт-маркетолог';

alter table bi_sendings_services 
modify column smsProvider
comment 'Провайдер СМС';

alter table bi_sendings_services 
modify column smppHost
comment 'Хост СМС';

alter table bi_sendings_services 
modify column smsSender
comment 'Отправитель СМС';

alter table bi_sendings_services 
modify column price_sms
comment 'Цена СМС';

alter table bi_sendings_services 
modify column price_smsProvider
comment 'Цена СМС провайдера';

alter table bi_sendings_services 
modify column flashCallProvider
comment 'Провайдер Flash Call';

alter table bi_sendings_services 
modify column confirmationProvider
comment 'Провайдер подтверждения';

alter table bi_sendings_services 
modify column price_flashCallProvider
comment 'Цена Flash Call';

alter table bi_sendings_services 
modify column emailFrom
comment 'Отправитель';

alter table bi_sendings_services 
modify column emailFromName
comment 'Отправитель';

alter table bi_sendings_services 
modify column viberProvider
comment 'Провайдер Viber';

alter table bi_sendings_services 
modify column price_viber
comment 'Цена Viber';
---------------

---------------
alter table bi_starts_detailed 
modify comment 'Детализированные данные по запуску брендов с расчётом бонусов менеджерам запуска';

alter table bi_starts_detailed 
modify column brand_id 
comment 'ID бренда';

alter table bi_starts_detailed 
modify column brand_name 
comment 'Наименование бренда';

alter table bi_starts_detailed 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_starts_detailed 
modify column salesManager 
comment 'Менеджер продаж';

alter table bi_starts_detailed 
modify column projectManager 
comment 'Менеджер запуска';

alter table bi_starts_detailed 
modify column dt 
comment 'День';

alter table bi_starts_detailed 
modify column status_int
comment 'ID статуса';

alter table bi_starts_detailed 
modify column last_dt
comment 'Флаг последнего календарного дня в витрине';

alter table bi_starts_detailed 
modify column status
comment 'Наименование статуса';

alter table bi_starts_detailed 
modify column soft
comment 'Софт бренда';

alter table bi_starts_detailed 
modify column start_dt
comment 'Дата запуска бренда';

alter table bi_starts_detailed 
modify column int_start_dt
comment 'Дата старта интеграции';

alter table bi_starts_detailed 
modify column archive_dt
comment 'Дата перевода бренда в архив';

alter table bi_starts_detailed 
modify column fee_start_first
comment 'Ежемесячная абонка при первом запуске бренда';

alter table bi_starts_detailed 
modify column fee_start
comment 'Ежемесячная абонка при запуске бренда (считается по сложной логике в т.ч. до момента фактического запуска)';

alter table bi_starts_detailed 
modify column days_on_int
comment 'Срок запуска бренда в днях (без учёта новогодних праздников)';

alter table bi_starts_detailed 
modify column clients_on_start
comment 'Число клиентов бренда при старте (считается с учётом прогноза по клиентской базе)';

alter table bi_starts_detailed 
modify column clients_forecast
comment 'Прогнозное число клиентов бренда';

alter table bi_starts_detailed 
modify column start_flag
comment 'Флаг запуска бренда';

alter table bi_starts_detailed 
modify column archive_flag
comment 'Флаг перевода бренда в архив';

alter table bi_starts_detailed 
modify column coeff
comment 'Коэффициент бонуса менеджера запуска';

alter table bi_starts_detailed 
modify column bonus
comment 'Сумма бонуса менеджера запуска';

alter table bi_starts_detailed 
modify column active_project_manager
comment 'Флаг активного менеджера запуска (не удалён из CRM)';
---------------

---------------
alter table bi_monthly_CR 
modify comment 'Данные по CR в запуск по месяцам (старая простая логика)';

alter table bi_monthly_CR 
modify column dt 
comment 'День';

alter table bi_monthly_CR 
modify column CR 
comment 'Конверсия в запуск';
---------------

---------------
alter table bi_daily_CR 
modify comment 'Данные по CR в запуск по дням (по сложной логике с окном 90 дней)';

alter table bi_daily_CR 
modify column dt 
comment 'День';

alter table bi_daily_CR 
modify column CR 
comment 'Конверсия в запуск';

alter table bi_daily_CR 
modify column brand_int 
comment 'Число брендов на интеграции для учёта в расчёте CR';

alter table bi_daily_CR 
modify column brand_starts 
comment 'Число запущенных брендов для учёта в расчёте CR';
---------------

---------------
alter table bi_daily_CR_manager 
modify comment 'Данные по CR в запуск по дням и по менеджерам запуска (по сложной логике с окном 90 дней)';

alter table bi_daily_CR_manager 
modify column projectManager 
comment 'Менеджер запуска';

alter table bi_daily_CR_manager 
modify column dt 
comment 'День';

alter table bi_daily_CR_manager 
modify column CR 
comment 'Конверсия в запуск';

alter table bi_daily_CR_manager 
modify column brand_int 
comment 'Число брендов на интеграции для учёта в расчёте CR';

alter table bi_daily_CR_manager 
modify column brand_starts 
comment 'Число запущенных брендов для учёта в расчёте CR';
---------------

---------------
alter table bi_daily_CR_pivot 
modify comment 'Данные по CR в запуск по дням и по менеджерам запуска с итоговым расчётом по всем менеджерам (по сложной логике с окном 90 дней)';

alter table bi_daily_CR_pivot 
modify column projectManager 
comment 'Менеджер запуска';

alter table bi_daily_CR_pivot 
modify column dt 
comment 'День';

alter table bi_daily_CR_pivot 
modify column CR 
comment 'Конверсия в запуск';

alter table bi_daily_CR_pivot 
modify column brand_int 
comment 'Число брендов на интеграции для учёта в расчёте CR';

alter table bi_daily_CR_pivot 
modify column brand_starts 
comment 'Число запущенных брендов для учёта в расчёте CR';
---------------

---------------
alter table bi_daily_CR_180
modify comment 'Данные по CR в запуск по дням (по сложной логике с окном 180 дней)';

alter table bi_daily_CR_180 
modify column dt 
comment 'День';

alter table bi_daily_CR_180 
modify column CR 
comment 'Конверсия в запуск';

alter table bi_daily_CR_180 
modify column brand_int 
comment 'Число брендов на интеграции для учёта в расчёте CR';

alter table bi_daily_CR_180 
modify column brand_starts 
comment 'Число запущенных брендов для учёта в расчёте CR';
---------------

---------------
alter table bi_daily_CR_manager_180 
modify comment 'Данные по CR в запуск по дням и по менеджерам запуска (по сложной логике с окном 180 дней)';

alter table bi_daily_CR_manager_180 
modify column projectManager 
comment 'Менеджер запуска';

alter table bi_daily_CR_manager_180 
modify column dt 
comment 'День';

alter table bi_daily_CR_manager_180 
modify column CR 
comment 'Конверсия в запуск';

alter table bi_daily_CR_manager_180 
modify column brand_int 
comment 'Число брендов на интеграции для учёта в расчёте CR';

alter table bi_daily_CR_manager_180 
modify column brand_starts 
comment 'Число запущенных брендов для учёта в расчёте CR';
---------------

---------------
alter table bi_daily_CR_pivot_180 
modify comment 'Данные по CR в запуск по дням и по менеджерам запуска с итоговым расчётом по всем менеджерам (по сложной логике с окном 180 дней)';

alter table bi_daily_CR_pivot_180 
modify column projectManager 
comment 'Менеджер запуска';

alter table bi_daily_CR_pivot_180 
modify column dt 
comment 'День';

alter table bi_daily_CR_pivot_180 
modify column CR 
comment 'Конверсия в запуск';

alter table bi_daily_CR_pivot_180 
modify column brand_int 
comment 'Число брендов на интеграции для учёта в расчёте CR';

alter table bi_daily_CR_pivot_180 
modify column brand_starts 
comment 'Число запущенных брендов для учёта в расчёте CR';
---------------

---------------
alter table bi_starts_detailed_w_CR 
modify comment 'Детализированные данные по запуску брендов с расчётом бонусов менеджерам запуска и с расчётом CR запуска';

alter table bi_starts_detailed_w_CR 
modify column brand_id 
comment 'ID бренда';

alter table bi_starts_detailed_w_CR 
modify column brand_name 
comment 'Наименование бренда';

alter table bi_starts_detailed_w_CR 
modify column accountManager 
comment 'Аккаунт-маркетолог';

alter table bi_starts_detailed_w_CR 
modify column salesManager 
comment 'Менеджер продаж';

alter table bi_starts_detailed_w_CR 
modify column projectManager 
comment 'Менеджер запуска';

alter table bi_starts_detailed_w_CR 
modify column dt 
comment 'День';

alter table bi_starts_detailed_w_CR 
modify column status_int
comment 'ID статуса';

alter table bi_starts_detailed_w_CR 
modify column last_dt
comment 'Флаг последнего календарного дня в витрине';

alter table bi_starts_detailed_w_CR 
modify column status
comment 'Наименование статуса';

alter table bi_starts_detailed_w_CR 
modify column soft
comment 'Софт бренда';

alter table bi_starts_detailed_w_CR 
modify column start_dt
comment 'Дата запуска бренда';

alter table bi_starts_detailed_w_CR 
modify column int_start_dt
comment 'Дата старта интеграции';

alter table bi_starts_detailed_w_CR 
modify column archive_dt
comment 'Дата перевода бренда в архив';

alter table bi_starts_detailed_w_CR 
modify column fee_start_first
comment 'Ежемесячная абонка при первом запуске бренда';

alter table bi_starts_detailed_w_CR 
modify column fee_start
comment 'Ежемесячная абонка при запуске бренда (считается по сложной логике в т.ч. до момента фактического запуска)';

alter table bi_starts_detailed_w_CR 
modify column days_on_int
comment 'Срок запуска бренда в днях (без учёта новогодних праздников)';

alter table bi_starts_detailed_w_CR 
modify column clients_on_start
comment 'Число клиентов бренда при старте (считается с учётом прогноза по клиентской базе)';

alter table bi_starts_detailed_w_CR 
modify column clients_forecast
comment 'Прогнозное число клиентов бренда';

alter table bi_starts_detailed_w_CR 
modify column start_flag
comment 'Флаг запуска бренда';

alter table bi_starts_detailed_w_CR 
modify column archive_flag
comment 'Флаг перевода бренда в архив';

alter table bi_starts_detailed_w_CR 
modify column coeff
comment 'Коэффициент бонуса менеджера запуска';

alter table bi_starts_detailed_w_CR 
modify column bonus
comment 'Сумма бонуса менеджера запуска';

alter table bi_starts_detailed_w_CR 
modify column active_project_manager
comment 'Флаг активного менеджера запуска (не удалён из CRM)';

alter table bi_starts_detailed_w_CR 
modify column CR_via_manager 
comment 'Конверсия в запуск по менеджеру запуска';
---------------

---------------
alter table bi_client_sendings 
modify comment 'Детальная аналитика рассылок по клиентам';

alter table bi_client_sendings 
modify column brand_id 
comment 'ID бренда';

alter table bi_client_sendings 
modify column brand_name 
comment 'Наименование бренда';

alter table bi_client_sendings 
modify column sending_type
comment 'Тип рассылки';

alter table bi_client_sendings 
modify column trigger_type
comment 'Тип триггера рассылки';

alter table bi_client_sendings 
modify column sending_name
comment 'Наименование рассылки';

alter table bi_client_sendings 
modify column sending_dow
comment 'День недели рассылки';

alter table bi_client_sendings 
modify column sending_hour
comment 'Час рассылки по часовому поясу клиента';

alter table bi_client_sendings 
modify column base_qty
comment 'База рассылки';

alter table bi_client_sendings 
modify column deliver
comment 'Число доставок';

alter table bi_client_sendings 
modify column open
comment 'Число открытых рассылок';

alter table bi_client_sendings 
modify column unsubscribe
comment 'Число отписок';

alter table bi_client_sendings 
modify column orders
comment 'Число чеков бренда';

alter table bi_client_sendings 
modify column revenue
comment 'Выручка бренда';

alter table bi_client_sendings 
modify column lost_sum
comment 'Затраты на скидки бренда';

alter table bi_client_sendings 
modify column lost_maxma
comment 'Затраты бренда на MAXMA';

alter table bi_client_sendings 
modify column sending_dt
comment 'Дата рассылки';

alter table bi_client_sendings 
modify column num_day_in_month
comment 'Порядковый номер недели в месяце';

alter table bi_client_sendings 
modify column channel
comment 'Каналы рассылок';

alter table bi_client_sendings 
modify column rev_type
comment 'Категория бренда по выручке';

alter table bi_client_sendings 
modify column industry
comment 'Индустрия бренда';
---------------

---------------
alter table bi_client_lost_reason 
modify comment 'Данные по причинам отключения брендов';

alter table bi_client_lost_reason 
modify column brand_id 
comment 'ID бренда';

alter table bi_client_lost_reason 
modify column brand_name 
comment 'Наименование бренда';

alter table bi_client_lost_reason 
modify column archiveReason
comment 'Причина отключения бренда (переноса в архив)';

alter table bi_client_lost_reason 
modify column archiveComment
comment 'Комментарий при отключении бренда';

alter table bi_client_lost_reason 
modify column alternative
comment 'Альтернатива продукту';

alter table bi_client_lost_reason 
modify column alternativeCompany
comment 'Конкурент к которому ушли';

alter table bi_client_lost_reason 
modify column possibleComeBack
comment 'Потенциальное возвращение';

alter table bi_client_lost_reason 
modify column possibleComeBackDate
comment 'Дата потенциального возвращения';

alter table bi_client_lost_reason 
modify column archiveInitiator
comment 'Иницииатор архивации';

alter table bi_client_lost_reason 
modify column monthly_fee
comment 'Ежемесячная абонка';

alter table bi_client_lost_reason 
modify column int_date
comment 'Дата начала интеграции';

alter table bi_client_lost_reason 
modify column last_fee_dt
comment 'Дата последнего списания абонки';

alter table bi_client_lost_reason 
modify column lost_dt
comment 'Дата перевода в архив';

alter table bi_client_lost_reason 
modify column days_on_int
comment 'Срок запуска бренда в днях (без учёта новогодних праздников)';

alter table bi_client_lost_reason 
modify column status
comment 'Наименование статуса';

alter table bi_client_lost_reason 
modify column LT
comment 'Накопительный срок жизни бренда (учитываем дни с выручкой)';

alter table bi_client_lost_reason 
modify column LTV
comment 'Накопительная выручка бренда';

alter table bi_client_lost_reason 
modify column accountManager
comment 'Аккаунт-маркетолог';

alter table bi_client_lost_reason 
modify column salesManager
comment 'Менеджер продаж';

alter table bi_client_lost_reason 
modify column projectManager
comment 'Менеджер запуска';

alter table bi_client_lost_reason 
modify column clients_qty_before_lost
comment 'Число клиентов бренда перед отключением';

alter table bi_client_lost_reason 
modify column industry
comment 'Индустрия бренда';

alter table bi_client_lost_reason 
modify column soft
comment 'Софт бренда';

alter table bi_client_lost_reason 
modify column shops_qty
comment 'Число торговых точек бренда';
---------------

---------------
alter table bi_referer_bonuses 
modify comment 'Данные по выплатам рефери';

alter table bi_referer_bonuses 
modify column referer 
comment 'Рефери';

alter table bi_referer_bonuses 
modify column inn 
comment 'ИНН рефери';

alter table bi_referer_bonuses 
modify column email 
comment 'Е-мейл рефери';

alter table bi_referer_bonuses 
modify column partner_name 
comment 'Наименование бренда';

alter table bi_referer_bonuses 
modify column brand_id 
comment 'ID бренда';

alter table bi_referer_bonuses 
modify column status
comment 'Наименование статуса';

alter table bi_referer_bonuses 
modify column int_date
comment 'Дата старта интеграции';

alter table bi_referer_bonuses 
modify column start_dt
comment 'Дата запуска бренда';

alter table bi_referer_bonuses 
modify column dt_mon
comment 'Месяц';

alter table bi_referer_bonuses 
modify column last_mon
comment 'Текущий месяц';

alter table bi_referer_bonuses 
modify column prelast_mon
comment 'Прошлый месяц';

alter table bi_referer_bonuses 
modify column curr_q
comment 'Текущий квартал';

alter table bi_referer_bonuses 
modify column curr_year
comment 'Текущий год';

alter table bi_referer_bonuses 
modify column mon_num
comment 'Порядковый номер месяца жизни бренда с момента запуска';

alter table bi_referer_bonuses 
modify column fee
comment 'Суммарное списание абонки за период';

alter table bi_referer_bonuses 
modify column tax
comment 'Налог на сумму списания абонки';

alter table bi_referer_bonuses 
modify column bonus
comment 'Бонус рефери от суммы списания абонки без налогов';

alter table bi_referer_bonuses 
modify column referer_bonus
comment 'Сумма бонуса рефери';
---------------

---------------
alter table bi_referer_settings 
modify comment 'Данные по условиям выплат рефери';
---------------

---------------
alter table bi_sales_manager_bonuses 
modify comment 'Данные по расчёту бонусов менеджерам продаж';

alter table bi_sales_manager_bonuses 
modify column salesManager
comment 'Менеджер продаж';

alter table bi_sales_manager_bonuses 
modify column client
comment 'Наименование бренда';

alter table bi_sales_manager_bonuses 
modify column brand_id
comment 'ID бренда';

alter table bi_sales_manager_bonuses 
modify column lead_type
comment 'Тип лида (бренда)';

alter table bi_sales_manager_bonuses 
modify column referer
comment 'Рефери бренда';

alter table bi_sales_manager_bonuses 
modify column status
comment 'Наименование статуса на дату';

alter table bi_sales_manager_bonuses 
modify column status_current
comment 'Наименование статуса текущего';

alter table bi_sales_manager_bonuses 
modify column int_date
comment 'Дата старта интеграции';

alter table bi_sales_manager_bonuses 
modify column start_dt
comment 'Дата запуска бренда';

alter table bi_sales_manager_bonuses 
modify column dt
comment 'День';

alter table bi_sales_manager_bonuses 
modify column start_pay
comment 'Дата старта базы оплаты';

alter table bi_sales_manager_bonuses 
modify column end_pay
comment 'Дата окончания базы оплаты';

alter table bi_sales_manager_bonuses 
modify column p_tm
comment 'Процент бонуса ТМ';

alter table bi_sales_manager_bonuses 
modify column p_tml
comment 'Процент бонуса лида ТМ';

alter table bi_sales_manager_bonuses 
modify column p_sm
comment 'Процент бонуса МП';

alter table bi_sales_manager_bonuses 
modify column p_sl
comment 'Процент бонуса лида МП';

alter table bi_sales_manager_bonuses 
modify column fee
comment 'Суммарное списание абонки за период';

alter table bi_sales_manager_bonuses 
modify column ref_mon_num
comment 'Порядковый номер месяца жизни бренда с момента запуска';

alter table bi_sales_manager_bonuses 
modify column ref_tax
comment 'Налог на сумму списания абонки';

alter table bi_sales_manager_bonuses 
modify column ref_bonus
comment 'Бонус рефери от суммы списания абонки без налогов';

alter table bi_sales_manager_bonuses 
modify column referer_bonus
comment 'Сумма бонуса рефери';

alter table bi_sales_manager_bonuses 
modify column tm_bonus
comment 'Сумма бонуса ТМ';

alter table bi_sales_manager_bonuses 
modify column tml_bonus
comment 'Сумма бонуса лида ТМ';

alter table bi_sales_manager_bonuses 
modify column manager_bonus
comment 'Сумма бонуса МП';

alter table bi_sales_manager_bonuses 
modify column leader_bonus
comment 'Сумма бонуса лида МП';
---------------

---------------
alter table bi_sales_bonus_settings 
modify comment 'Данные по условиям выплат бонусов ТМ и МП';
---------------

---------------
alter table bi_product_moduls_revenue_lost_maxma 
modify comment 'Аллокация затрат брендов на MAXMA по модулям и подмодулям продукта';

alter table bi_product_moduls_revenue_lost_maxma 
modify column brand_id 
comment 'ID бренда';

alter table bi_product_moduls_revenue_lost_maxma 
modify column dt 
comment 'День';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_auto_lost_maxma
comment 'Затраты бренда на автоматические рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_hand_lost_maxma
comment 'Затраты бренда на ручные рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_adcart_lost_maxma
comment 'Затраты бренда на рассылки по брошенным корзинам';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_auto_sms_lost_maxma
comment 'Затраты бренда на автоматические СМС рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_hand_sms_lost_maxma
comment 'Затраты бренда на ручные СМС рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_auto_push_lost_maxma
comment 'Затраты бренда на автоматические пуш рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_hand_push_lost_maxma
comment 'Затраты бренда на ручные пуш рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_auto_email_lost_maxma
comment 'Затраты бренда на автоматические е-мейл рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_hand_email_lost_maxma
comment 'Затраты бренда на ручные е-мейл рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_auto_viber_lost_maxma
comment 'Затраты бренда на автоматические Viber рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column sendings_hand_viber_lost_maxma
comment 'Затраты бренда на ручные Viber рассылки';

alter table bi_product_moduls_revenue_lost_maxma 
modify column rfm_lost_maxma
comment 'Затраты бренда на RFM';

alter table bi_product_moduls_revenue_lost_maxma 
modify column wallet_lost_maxma
comment 'Затраты бренда на Wallet';
---------------

---------------
alter table bi_product_moduls_revenue 
modify comment 'Аллокация выручки и потерь брендов на акции и скидки по модулям и подмодулям продукта';

alter table bi_product_moduls_revenue 
modify column brand_id 
comment 'ID бренда';

alter table bi_product_moduls_revenue 
modify column dt 
comment 'День';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_auto
comment 'Выручка бренда с автоматических рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_auto
comment 'Потери бренда на скидках и акциях с автоматических рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_hand
comment 'Выручка бренда с ручных рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_hand
comment 'Потери бренда на скидках и акциях с ручных рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_adcart
comment 'Выручка бренда с рассылок по брошенным корзинам';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_adcart
comment 'Потери бренда на скидках и акциях с рассылок по брошенным корзинам';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_auto_sms
comment 'Выручка бренда с автоматических СМС рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_auto_sms
comment 'Потери бренда на скидках и акциях с автоматических СМС рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_hand_sms
comment 'Выручка бренда с ручных СМС рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_hand_sms
comment 'Потери бренда на скидках и акциях с ручных СМС рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_auto_push
comment 'Выручка бренда с автоматических пуш рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_auto_push
comment 'Потери бренда на скидках и акциях с автоматических пуш рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_hand_push
comment 'Выручка бренда с ручных пуш рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_hand_push
comment 'Потери бренда на скидках и акциях с ручных пуш рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_auto_email
comment 'Выручка бренда с автоматических е-мейл рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_auto_email
comment 'Потери бренда на скидках и акциях с автоматических е-мейл рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_hand_email
comment 'Выручка бренда с ручных е-мейл рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_hand_email
comment 'Потери бренда на скидках и акциях с ручных е-мейл рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_auto_viber
comment 'Выручка бренда с автоматических Viber рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_auto_viber
comment 'Потери бренда на скидках и акциях с автоматических Viber рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_sendings_hand_viber
comment 'Выручка бренда с ручных Viber рассылок';

alter table bi_product_moduls_revenue 
modify column lost_sum_sendings_hand_viber
comment 'Потери бренда на скидках и акциях с ручных Viber рассылок';

alter table bi_product_moduls_revenue 
modify column revenue_offer
comment 'Выручка бренда с акций';

alter table bi_product_moduls_revenue 
modify column lost_sum_offer
comment 'Потери бренда на акциях';

alter table bi_product_moduls_revenue 
modify column revenue_promocode
comment 'Выручка бренда с промокодов';
alter table bi_product_moduls_revenue 
modify column lost_sum_promocode
comment 'Потери бренда на промокодах';

alter table bi_product_moduls_revenue 
modify column revenue_promo_friend
comment 'Выручка бренда с акции Приведи друга';

alter table bi_product_moduls_revenue 
modify column lost_sum_promo_friend
comment 'Потери бренда на акции Приведи друга';

alter table bi_product_moduls_revenue 
modify column revenue_gift_card
comment 'Выручка бренда с подарочных карт';

alter table bi_product_moduls_revenue 
modify column lost_sum_gift_card
comment 'Потери бренда на подарочных картах';

alter table bi_product_moduls_revenue 
modify column revenue_base
comment 'Выручка бренда с основного продукта';

alter table bi_product_moduls_revenue 
modify column lost_sum_base
comment 'Потери бренда на основном продукте';

alter table bi_product_moduls_revenue 
modify column revenue_rfm
comment 'Выручка бренда с RFM';

alter table bi_product_moduls_revenue 
modify column lost_sum_rfm
comment 'Потери бренда на RFM';

alter table bi_product_moduls_revenue 
modify column revenue_lead_form
comment 'Выручка бренда с Лид-формы';

alter table bi_product_moduls_revenue 
modify column lost_sum_lead_form
comment 'Потери бренда на Лид-форме';

alter table bi_product_moduls_revenue 
modify column revenue_wallet
comment 'Выручка бренда с Wallet';

alter table bi_product_moduls_revenue 
modify column lost_sum_wallet
comment 'Потери бренда на Wallet';
---------------

---------------
alter table bi_product_moduls 
modify comment 'Оценка эффективности работы модулей продукта';

alter table bi_product_moduls 
modify column brand_id 
comment 'ID бренда';

alter table bi_product_moduls 
modify column brand_name
comment 'Наименование бренда';

alter table bi_product_moduls 
modify column industry
comment 'Индустрия бренда';

alter table bi_product_moduls 
modify column soft
comment 'Софт бренда';

alter table bi_product_moduls 
modify column accountManager
comment 'Аккаунт-маркетолог';

alter table bi_product_moduls 
modify column dt
comment 'День';

alter table bi_product_moduls 
modify column status
comment 'Наименование статуса';

alter table bi_product_moduls 
modify column status_num
comment 'ID статуса';

alter table bi_product_moduls 
modify column module_name
comment 'Модуль продукта';

alter table bi_product_moduls 
modify column sub_module_name
comment 'Подмодуль продукта';

alter table bi_product_moduls 
modify column low_module_name
comment 'Детализация подмодуля продукта';

alter table bi_product_moduls 
modify column activation
comment 'Флаг активного модуля';

alter table bi_product_moduls 
modify column usage_qty
comment 'Число событий использования модуля';

alter table bi_product_moduls 
modify column revenue
comment 'Выручка';

alter table bi_product_moduls 
modify column lost_sum
comment 'Потери от акций и скидок';

alter table bi_product_moduls 
modify column lost_maxma
comment 'Потери из-за использования MAXMA';

alter table bi_product_moduls 
modify column daily_fee
comment 'Ежедневное списание абонки';

alter table bi_product_moduls 
modify column module_ltv
comment 'Накопленная сумма абонки на дату';

alter table bi_product_moduls 
modify column module_lt
comment 'Число дней со списанием абонки на дату';

alter table bi_product_moduls 
modify column release_dt
comment 'Дата первого релиза модуля';
---------------

---------------
alter table bi_module_release_date 
modify comment 'Данные по дате релиза модулей';
---------------

---------------
alter table bi_daily_CR_sales_manager_and_lead_type 
modify comment 'Данные по конверсиям в запуск по менеджерам продаж';

alter table bi_daily_CR_sales_manager_and_lead_type 
modify column salesManager
comment 'Менеджер продаж';

alter table bi_daily_CR_sales_manager_and_lead_type 
modify column lead_type
comment 'Тип лида (бренда)';

alter table bi_daily_CR_sales_manager_and_lead_type 
modify column dt
comment 'День';

alter table bi_daily_CR_sales_manager_and_lead_type 
modify column CR
comment 'Конверсия в запуск по менеджеру продаж';

alter table bi_daily_CR_sales_manager_and_lead_type 
modify column brand_int
comment 'Число брендов на интеграции';

alter table bi_daily_CR_sales_manager_and_lead_type 
modify column brand_starts
comment 'Число запущенных брендов';
---------------

---------------
alter table bi_daily_sales_manager_report 
modify comment 'Данные по оценке менеджеров продаж по дням';

alter table bi_daily_sales_manager_report 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_sales_manager_report 
modify column brand_name
comment 'Наименование бренда';

alter table bi_daily_sales_manager_report 
modify column lead_type
comment 'Тип лида (бренда)';

alter table bi_daily_sales_manager_report 
modify column salesManager
comment 'Менеджер продаж';

alter table bi_daily_sales_manager_report 
modify column active_manager
comment 'Флаг активного менеджера продаж (не удалён из CRM)';

alter table bi_daily_sales_manager_report 
modify column dt
comment 'День';

alter table bi_daily_sales_manager_report 
modify column contract
comment 'Число заключённых договоров';

alter table bi_daily_sales_manager_report 
modify column contract_fee
comment 'Сумма заключённых договоров (в ежемесячной абонке)';

alter table bi_daily_sales_manager_report 
modify column started
comment 'Число запущенных клиентов';

alter table bi_daily_sales_manager_report 
modify column started_fee
comment 'Сумма абонки по запущенным клиентам';

alter table bi_daily_sales_manager_report 
modify column started_fee_first
comment 'Сумма абонки по запущенным клиентам (при первом запуске)';

alter table bi_daily_sales_manager_report 
modify column days_on_int
comment 'Срок запуска бренда в днях (без учёта новогодних праздников)';

alter table bi_daily_sales_manager_report 
modify column LTV
comment 'Прогнозный расчёт LTV бренда (по индустриям)';

alter table bi_daily_sales_manager_report 
modify column LT
comment 'Базовое значение LT для расчёта прогноза LTV (по менеджерам продаж)';

alter table bi_daily_sales_manager_report 
modify column lost_stopped
comment 'Число приостановленных или заархивированных брендов';

alter table bi_daily_sales_manager_report 
modify column lost_stopped_fee
comment 'Последняя абонка по приостановленным или заархивированным брендам';

alter table bi_daily_sales_manager_report 
modify column brand_int
comment 'Число брендов на интеграции (для расчёта CR)';

alter table bi_daily_sales_manager_report 
modify column brand_starts
comment 'Число запущенных брендов (для расчёта CR)';
---------------

---------------
alter table bi_daily_sales_manager_report_cohort 
modify comment 'Когортные данные по оценке менеджеров продаж по дню старта интеграции';

alter table bi_daily_sales_manager_report_cohort 
modify column brand_id 
comment 'ID бренда';

alter table bi_daily_sales_manager_report_cohort 
modify column brand_name
comment 'Наименование бренда';

alter table bi_daily_sales_manager_report_cohort 
modify column lead_type
comment 'Тип лида (бренда)';

alter table bi_daily_sales_manager_report_cohort 
modify column dt_int
comment 'День старта интеграции бренда';

alter table bi_daily_sales_manager_report_cohort 
modify column salesManager
comment 'Менеджер продаж';

alter table bi_daily_sales_manager_report_cohort 
modify column active_manager
comment 'Флаг активного менеджера продаж (не удалён из CRM)';

alter table bi_daily_sales_manager_report_cohort 
modify column contract
comment 'Число заключённых договоров';

alter table bi_daily_sales_manager_report_cohort 
modify column contract_fee
comment 'Сумма заключённых договоров (в ежемесячной абонке)';

alter table bi_daily_sales_manager_report_cohort 
modify column started
comment 'Число запущенных клиентов';

alter table bi_daily_sales_manager_report_cohort 
modify column started_fee
comment 'Сумма абонки по запущенным клиентам';

alter table bi_daily_sales_manager_report_cohort 
modify column started_fee_first
comment 'Сумма абонки по запущенным клиентам (при первом запуске)';

alter table bi_daily_sales_manager_report_cohort 
modify column days_on_int
comment 'Срок запуска бренда в днях (без учёта новогодних праздников)';

alter table bi_daily_sales_manager_report_cohort 
modify column lost_stopped
comment 'Число приостановленных или заархивированных брендов';

alter table bi_daily_sales_manager_report_cohort 
modify column lost_stopped_fee
comment 'Последняя абонка по приостановленным или заархивированным брендам';

alter table bi_daily_sales_manager_report_cohort 
modify column LTV_on_date
comment 'Накопительная выручка бренда';

alter table bi_daily_sales_manager_report_cohort 
modify column LT_on_date
comment 'Накопительный срок жизни бренда (учитываем дни с выручкой)';
---------------

---------------
alter table bi_monthly_account_manager_data 
modify comment 'По-месячные данные по аккаунт-маркетологам';

alter table bi_monthly_account_manager_data 
modify column accountManager
comment 'Аккаунт-маркетолог';

alter table bi_monthly_account_manager_data 
modify column mon
comment 'Месяц';

alter table bi_monthly_account_manager_data 
modify column active_brands
comment 'Число активных брендов';

alter table bi_monthly_account_manager_data 
modify column active_brands_pre_mon
comment 'Число активных брендов в прошлом месяце';

alter table bi_monthly_account_manager_data 
modify column ready_brands
comment 'Число брендов в подготовке к запуску';

alter table bi_monthly_account_manager_data 
modify column pilot_brands
comment 'Число брендов в пилоте';

alter table bi_monthly_account_manager_data 
modify column fee_sum
comment 'Сумма ежемесячной абонки активных брендов на конец месяца';

alter table bi_monthly_account_manager_data 
modify column fee_sum_pre_mon
comment 'Сумма ежемесячной абонки активных брендов на конец предыдущего месяца';

alter table bi_monthly_account_manager_data 
modify column fee_up_rollup
comment 'Положительные изменения абонки за месяц (сумма всех изменений в течение месяца, атрибуцированная к дате наибольшего роста абонки)';

alter table bi_monthly_account_manager_data 
modify column fee_down_rollup
comment 'Отрицательные изменения абонки за месяц (сумма всех изменений в течение месяца, атрибуцированная к дате наибольшего падения абонки)';

alter table bi_monthly_account_manager_data 
modify column up_brands
comment 'Число брендов с положительным месячным изменением абонки (более 1000 руб.)';

alter table bi_monthly_account_manager_data 
modify column down_brands
comment 'Число брендов с отрицательным месячным изменением абонки (более 1000 руб.)';

alter table bi_monthly_account_manager_data 
modify column stopped_archived_fee
comment 'Сумма последнего значения ежемесячной абонки брендов, которые были приостановлены или заархивированы';

alter table bi_monthly_account_manager_data 
modify column stopped_lost_brands
comment 'Число брендов, которые были приостановлены или заархивированы';
---------------

---------------
alter table bi_brand_and_tariff 
modify comment 'Данные по атрибутам и текущим тарифам брендов';

alter table bi_brand_and_tariff 
modify column brand_name
comment 'Наименование бренда';

alter table bi_brand_and_tariff 
modify column status
comment 'Наименование статуса';

alter table bi_brand_and_tariff 
modify column accountManager
comment 'Аккаунт-маркетоло';

alter table bi_brand_and_tariff 
modify column industry
comment 'Индустрия бренда';

alter table bi_brand_and_tariff 
modify column clients_qty
comment 'Число клиентов бренда';

alter table bi_brand_and_tariff 
modify column clients_w_wallet_qty
comment 'Число клиентов бренда с Wallet';

alter table bi_brand_and_tariff 
modify column tariff_name
comment 'Название тарифа';

alter table bi_brand_and_tariff 
modify column tariff_fee
comment 'Стоимость ежемесячной абонки по тарифу';

alter table bi_brand_and_tariff 
modify column fee
comment 'Сумма последнего списания абонки (приведённая к месячной)';

alter table bi_brand_and_tariff 
modify column balance
comment 'Текущий баланс';

alter table bi_brand_and_tariff 
modify column balanceThreshold
comment 'Порог баланса';

alter table bi_brand_and_tariff 
modify column autoSuspend
comment 'Автоприостановка';

alter table bi_brand_and_tariff 
modify column LT
comment 'Накопительный срок жизни бренда (учитываем дни с выручкой)';

alter table bi_brand_and_tariff 
modify column shops_qty
comment 'Число торговых точек бренда';

alter table bi_brand_and_tariff 
modify column soft
comment 'Софт бренда';

alter table bi_brand_and_tariff 
modify column projectManager
comment 'Менеджер запуска';

alter table bi_brand_and_tariff 
modify column module_form
comment 'Модуль Форма';

alter table bi_brand_and_tariff 
modify column module_wallet_card
comment 'Модуль Wallet';

alter table bi_brand_and_tariff 
modify column module_email
comment 'Модуль Email';

alter table bi_brand_and_tariff 
modify column module_offer
comment 'Модуль Акции';

alter table bi_brand_and_tariff 
modify column module_smart_rfm
comment 'Модуль SmartRFM';

alter table bi_brand_and_tariff 
modify column module_gift_card
comment 'Модуль Сертификат';

alter table bi_brand_and_tariff 
modify column module_marketing_support
comment 'Модуль Сопровождение';

alter table bi_brand_and_tariff 
modify column module_custom_report
comment 'Модуль Выгрузка';

alter table bi_brand_and_tariff 
modify column module_iiko
comment 'Модуль IIKO';

alter table bi_brand_and_tariff 
modify column module_ecommerce
comment 'Модуль ECommerce';

alter table bi_brand_and_tariff 
modify column module_sms_signature
comment 'Модуль Подпись SMS';

alter table bi_brand_and_tariff 
modify column module_extra_sender
comment 'Модуль Доп. имя отправителя';

alter table bi_brand_and_tariff 
modify column module_tg_bot
comment 'Модуль Telegram-бот';
---------------

---------------
alter table bi_brands_potential 
modify comment 'Данные для оценки потенциала развития базы';

alter table bi_brands_potential 
modify column brand_id 
comment 'ID бренда';

alter table bi_brands_potential 
modify column brand_name
comment 'Наименование бренда';

alter table bi_brands_potential 
modify column status_name
comment 'Наименование статуса';

alter table bi_brands_potential 
modify column accountManager
comment 'Аккаунт-маркетолог';

alter table bi_brands_potential 
modify column LT
comment 'Накопительный срок жизни бренда (учитываем дни с выручкой)';

alter table bi_brands_potential 
modify column clients
comment 'Число клиентов бренда';

alter table bi_brands_potential 
modify column clients_wallet
comment 'Число клиентов бренда с Wallet';

alter table bi_brands_potential 
modify column clients_on_start
comment 'Число клиентов бренда на момент окончания пилота';

alter table bi_brands_potential 
modify column clients_2022
comment 'Число клиентов бренда на конец 2022 года';

alter table bi_brands_potential 
modify column clients_2023
comment 'Число клиентов бренда на конец 2023 года';

alter table bi_brands_potential 
modify column clients_2024
comment 'Число клиентов бренда на конец 2024 года';

alter table bi_brands_potential 
modify column tariff_name
comment 'Название тарифа';

alter table bi_brands_potential 
modify column current_tariff
comment 'Текущий тариф бренда';

alter table bi_brands_potential 
modify column upper_clients_border
comment 'Верхняя граница клиентов по текущему тарифу';

alter table bi_brands_potential 
modify column next_tariff
comment 'Следующий тариф бренда (на ступень выше)';

alter table bi_brands_potential 
modify column price_per_client
comment 'Стоимость одного клиента сверх границы';

alter table bi_brands_potential 
modify column next_price_per_client
comment 'Стоимость одного клиента сверх границы на следующей ступени тарифа';

alter table bi_brands_potential 
modify column monthly_clients_growth
comment 'Средний ежемесячный рост клиетов бренда за последние полгода';

alter table bi_brands_potential 
modify column fee_dynamic_2022
comment 'Средняя динамика абонентской платы за 2022 год';

alter table bi_brands_potential 
modify column fee_dynamic_2023
comment 'Средняя динамика абонентской платы за 2023 год';

alter table bi_brands_potential 
modify column fee_dynamic_2024
comment 'Средняя динамика абонентской платы за 2024 год';

alter table bi_brands_potential 
modify column fee_dynamic
comment 'Средняя динамика абонентской платы за время жизни бренда';

alter table bi_brands_potential 
modify column monthly_revenue
comment 'Средняя ежемесячная выручка бренда за последние полгода';
---------------

---------------
alter table bi_brands_criticality 
modify comment 'Данные для оценки потенциала критичности базы по дням';

alter table bi_brands_criticality 
modify column brand_id 
comment 'ID бренда';

alter table bi_brands_criticality 
modify column brand_name
comment 'Наименование бренда';

alter table bi_brands_criticality 
modify column status_name
comment 'Наименование статуса';

alter table bi_brands_criticality 
modify column accountManager
comment 'Аккаунт-маркетолог';

alter table bi_brands_criticality 
modify column dt
comment 'День';

alter table bi_brands_criticality 
modify column daily_fee
comment 'Ежедневное списание абонки';

alter table bi_brands_criticality 
modify column LT
comment 'Накопительный срок жизни бренда на день (учитываем дни с выручкой)';

alter table bi_brands_criticality 
modify column clients
comment 'Число клиентов бренда на дату';

alter table bi_brands_criticality 
modify column revenue
comment 'Выручка бренда';

alter table bi_brands_criticality 
modify column pl_revenue
comment 'Выручка бренда с программой лояльности';

alter table bi_brands_criticality 
modify column orders
comment 'Чеки бренда';

alter table bi_brands_criticality 
modify column pl_orders
comment 'Чеки бренда с программой лояльности';

alter table bi_brands_criticality 
modify column sendings_qty
comment 'Число рассылок бренда';

alter table bi_brands_criticality 
modify column analytics_usage_qty
comment 'Число использований раздела Аналитика';

alter table bi_brands_criticality 
modify column operators_qty
comment 'Число пользователей платформы у бренда';

alter table bi_brands_criticality 
modify column offer_synth_id
comment 'Синтетический ID акции';

alter table bi_brands_criticality 
modify column dt_offer_start
comment 'Дата старта акции';

alter table bi_brands_criticality 
modify column row_type
comment 'Тип строки (для расчёта основных метрик или метрик, связанных с рассылками и акциями)';
---------------

---------------
alter table bi_brands_research_purchase 
modify comment 'Промежуточные данные для ежегодных исследований (данные по покупкам брендов)';

alter table bi_brands_research_purchase 
modify column mon 
comment 'Месяц';

alter table bi_brands_research_purchase 
modify column brand_id 
comment 'ID бренда';

alter table bi_brands_research_purchase 
modify column row_type
comment 'Тип строки (для итоговой таблицы)';

alter table bi_brands_research_purchase 
modify column bonuses_lp
comment 'Применение бонусов';

alter table bi_brands_research_purchase 
modify column offer_lp
comment 'Применение акций';

alter table bi_brands_research_purchase 
modify column total_purchases
comment 'Число чеков';

alter table bi_brands_research_purchase 
modify column revenue
comment 'Выручка';

alter table bi_brands_research_purchase 
modify column pl_purchases
comment 'Число чеков с программой лояльности';

alter table bi_brands_research_purchase 
modify column common_promocodes
comment 'Использование общих промокодов';

alter table bi_brands_research_purchase 
modify column personal_promocodes
comment 'Использование персональных промокодов';
---------------

---------------
alter table bi_brands_research 
modify comment 'Данные для ежегодных исследований';

alter table bi_brands_research 
modify column mon 
comment 'Месяц';

alter table bi_brands_research
modify column brand_id 
comment 'ID бренда';

alter table bi_brands_research
modify column brand_name
comment 'Наименование бренда';

alter table bi_brands_research
modify column row_type
comment 'Тип строки (для расчёта разных типов метрик)';

alter table bi_brands_research
modify column bonuses_lp
comment 'Применение бонусов';

alter table bi_brands_research
modify column offer_lp
comment 'Применение акций';

alter table bi_brands_research
modify column total_purchases
comment 'Число чеков';

alter table bi_brands_research
modify column revenue
comment 'Выручка';

alter table bi_brands_research
modify column pl_purchases
comment 'Число чеков с программой лояльности';

alter table bi_brands_research
modify column common_promocodes
comment 'Использование общих промокодов';

alter table bi_brands_research
modify column personal_promocodes
comment 'Использование персональных промокодов';

alter table bi_brands_research
modify column levels_qty
comment 'Число уровней в программе лояльности';

alter table bi_brands_research
modify column min_cashback
comment 'Минимальный % кэшбэка в программе лояльности';

alter table bi_brands_research
modify column max_cashback
comment 'Максимальный % кэшбэка в программе лояльности';

alter table bi_brands_research
modify column min_spent_level
comment 'Минимальный уровень покупок для кэшбэка в программе лояльности';

alter table bi_brands_research
modify column max_spent_level
comment 'Максимальный уровень покупок для кэшбэка в программе лояльности';

alter table bi_brands_research
modify column rev_type
comment 'Категория бренда по выручке';

alter table bi_brands_research
modify column industry
comment 'Индустрия бренда';

alter table bi_brands_research
modify column industry_group
comment 'Группа индустрии бренда';

alter table bi_brands_research
modify column soft
comment 'Софт бренда';

alter table bi_brands_research
modify column clients_segment
comment 'Сегмент по числу клиентов бренда';

alter table bi_brands_research
modify column wallet
comment 'Подключение Wallet';

alter table bi_brands_research
modify column tg_bot
comment 'Подключение Telegram-бота';

alter table bi_brands_research
modify column rfm
comment 'Подключение SmartRFM';

alter table bi_brands_research
modify column sending_name
comment 'Наименование рассылки';

alter table bi_brands_research
modify column channels
comment 'Каналы рассылок';

alter table bi_brands_research
modify column sending_type
comment 'Тип рассылки';

alter table bi_brands_research
modify column sended
comment 'Число отправлений';

alter table bi_brands_research
modify column delivered
comment 'Число доставок';

alter table bi_brands_research
modify column opened
comment 'Число открытых рассылок';

alter table bi_brands_research
modify column orders
comment 'Число чеков бренда';

alter table bi_brands_research
modify column dr
comment 'Delivery rate';

alter table bi_brands_research
modify column or
comment 'Open rate';

alter table bi_brands_research
modify column sor
comment 'CR в заказы из открытых';

alter table bi_brands_research
modify column sdr
comment 'CR в заказы из доставленных';
