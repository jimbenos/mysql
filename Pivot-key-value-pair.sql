-- truncate target table
truncate table [sandbox-db].[dbo].[program_participants];

-- insert into target table
select distinct
    -- participant details
    isnull(pm.[primary id], f.[participant id]) as [participant id],
    f.[form id],
    convert(date, p.[date of birth]) as [date of birth],
    p.[gender],
    p.[demographic status],
    case
        when p.[clinic region] like '%(%' 
            then substring(
                    p.[clinic region],
                    charindex('(', p.[clinic region]) + 1,
                    charindex(')', p.[clinic region]) - charindex('(', p.[clinic region]) - 1
                )
        when p.[clinic region] like '%community%'
            then substring(p.[clinic region], 
                  charindex(' ', p.[clinic region], charindex(' ', p.[clinic region]) + 1) + 1,
                  len(p.[clinic region]))
        else p.[clinic region]  
    end as [clinic region],
    p.[primary organization],
    p.[active status],
    p.[test participant],

    -- form details
    f.[create timestamp],
    f.[created by],
    f.[creator organization],
    f.[is completed],
    f.[is archived],

    -- program details
    case
        when rd.[enrollment date] like '__/__/____%m' 
            then try_convert(date, rd.[enrollment date], 103) 
        when rd.[enrollment date] like '__/__/____' 
            then try_convert(date, rd.[enrollment date], 103)
        when rd.[enrollment date] like '____-__-__' 
            then try_convert(date, rd.[enrollment date], 23) 
        else null
    end as [enrollment date],
    rd.[program name],
    case
        when rd.[referring center] like '%(%'
            then substring(rd.[referring center],
                    charindex('(', rd.[referring center]) +1,
                    charindex(')', rd.[referring center]) - charindex('(', rd.[referring center]) -1
                    )
        else rd.[referring center]
    end as [referring center],
    ig.[program type],
    rd.[program location],
    case
        when rd.[location other] = 'nil'
            then null
        else rd.[location other]
    end as [location other],

    -- status details
    cs.[current status],

    -- completion details
    case
        when dd.[exit date] like '__/__/____%m' 
            then try_convert(date, dd.[exit date], 103) 
        when dd.[exit date] like '__/__/____' 
            then try_convert(date, dd.[exit date], 103)
        when dd.[exit date] like '____-__-__' 
            then try_convert(date, dd.[exit date], 23) 
        else null
    end as [exit date],
    dd.[exit reason],
    rt.[referred to]
from [source-db].[raw].[forms] as f
left join [source-db].[raw].[participantmerge] pm
    on f.[participant id] = pm.[secondary id]
    and pm.[rct] != 'd'    
    and pm.[unmerge timestamp] is null
    and pm.[rcurrent] = 1
left join [source-db].[transform].[participant_details] p
    on isnull(pm.[primary id], f.[participant id]) = p.[participant id]
left join [source-db].[raw].[formdata] fd
    on f.[form id] = fd.[form id]
    and fd.[rct] != 'd'
    and fd.[rcurrent] = 1
left join (
    -- enrollment details subquery
    select 
        [form id],
        [enrollment date],
        [program name],
        [program location],
        [location other],
        [referring center]
    from (
        select distinct
            [form id],
            case
                when [key] = 'enrollmentdate' then 'enrollment date'
                when [key] = 'program.text' then 'program name'
                when [key] = 'location.value' then 'program location'
                when [key] = 'locationother' then 'location other'
                when [key] = 'referringcenter.name' then 'referring center'                
            end as [keyname],
            [value],
            row_number() over (partition by [form id], [key] order by [rfdts] desc) as rn
        from [source-db].[raw].[formdata]
        where [key] in (
            'enrollmentdate',
            'program.text',
            'location.value',
            'locationother',
            'referringcenter.name'
        )
        and [rct] != 'd'
        and [rcurrent] = 1
    ) rd
    pivot (
        max([value])
        for [keyname] in (
            [enrollment date],
            [program name],
            [program location],
            [location other],
            [referring center]
        )
    ) as pvt
    where rn = 1
) rd on f.[form id] = rd.[form id]
left join (
    -- program type subquery
    select
        [form id],
        [program type]
    from (
        select distinct
            [form id],
            [value] as [program type],
            row_number() over (partition by [form id], [key] order by [rfdts] desc) as rn
        from [source-db].[raw].[formdata]
        where [key] like 'programtype%.value'
        and [rct] != 'd'
        and [rcurrent] = 1
    ) t
    where rn = 1
) ig on f.[form id] = ig.[form id]
left join (
    -- current status subquery
    select
        [form id],
        [current status]
    from (
        select distinct
            [form id],
            [value] as [current status],
            row_number() over (partition by [form id], [key] order by [rfdts] desc) as rn
        from [source-db].[raw].[formdata]
        where [key] = 'currentstatus.value'
        and [rct] != 'd'
        and [rcurrent] = 1
    ) t
    where rn = 1
) cs on f.[form id] = cs.[form id]
left join (
    -- exit details subquery
    select 
        [form id],
        [exit date],
        [exit reason]
    from (
        select distinct
            [form id],
            case
                when [key] = 'exitdate' then 'exit date'
                when [key] = 'exitreason.text' then 'exit reason'    
            end as [keyname],
            [value],
            row_number() over (partition by [form id], [key] order by [rfdts] desc) as rn
        from [source-db].[raw].[formdata]
        where [key] in (
            'exitdate',
            'exitreason.text'
        )
        and [rct] != 'd'
        and [rcurrent] = 1
    ) t
    pivot (
        max([value])
        for [keyname] in (
            [exit date],
            [exit reason]
        )
    ) as pvt
    where rn = 1
) dd on f.[form id] = dd.[form id]
left join (
    -- referral subquery
    select
        [form id],
        [referred to]
    from (
        select distinct
            [form id],
            [value] as [referred to],
            row_number() over (partition by [form id], [key] order by [rfdts] desc) as rn
        from [source-db].[raw].[formdata]
        where [key] like 'exitreferred%.text'
        and [rct] != 'd'
        and [rcurrent] = 1
    ) t
    where rn = 1
) rt on f.[form id] = rt.[form id]
where
    f.[name] = 'community health programs'
    and f.[rct] != 'd'
    and f.[rcurrent] = 1
    and rd.[program name] = 'healthy living program';