SELECT ul.ds_nome_consulta AS "Magistrado"
     -- T952 - Sentencas e Acordos de Conhecimento
     -- Acordos
     , '$URL/execucao/T953?MAGISTRADO=' || mag.id
           || '&SENTENCA_OU_ACORDO=2'
           || '&DATA_INICIAL_OPCIONAL=' ||
       to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date, 'mm/dd/yyyy')
           || '&DATA_OPCIONAL_FINAL=' || to_char(coalesce(:DATA_OPCIONAL_FINAL, current_date)::date, 'mm/dd/yyyy')
                  AS "Conciliações"
     , '$URL/execucao/T953?MAGISTRADO=' || mag.id
           || '&SENTENCA_OU_ACORDO=1'
           || '&DATA_INICIAL_OPCIONAL=' ||
       to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date, 'mm/dd/yyyy')
           || '&DATA_OPCIONAL_FINAL=' || to_char(coalesce(:DATA_OPCIONAL_FINAL, current_date)::date, 'mm/dd/yyyy')
                  AS "Sentenças de Conhecimento Proferidas"
     -- T950 Sentencas pendentes
     , '$URL/execucao/T951?MAGISTRADO=' || mag.id
           || '&DATA_OPCIONAL_FINAL='
    || to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date, 'mm/dd/yyyy')
                  AS "Sentenças de conhecimento pendentes"
     -- T963 EDs Julgados
     , '$URL/execucao/T961?MAGISTRADO=' || mag.id
           || '&DATA_INICIAL_OPCIONAL=' ||
       to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date, 'mm/dd/yyyy')
           || '&DATA_OPCIONAL_FINAL=' || to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date, 'mm/dd/yyyy')
                  AS "Embargos Declaratórios Julgados"
     -- T958 - EDs pendentes
     , '$URL/execucao/T959?MAGISTRADO=' || mag.id
           || '&DATA_OPCIONAL_FINAL='
    || to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date, 'mm/dd/yyyy')
                  AS "Embargos Declaratórios Pendentes"
     -- T956 - Incidentes de Execucao Julgados
     , '$URL/execucao/T957?MAGISTRADO=' || mag.id
           || '&DATA_INICIAL_OPCIONAL=' ||
       to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date, 'mm/dd/yyyy')
           || '&DATA_OPCIONAL_FINAL=' || to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date, 'mm/dd/yyyy')
                  AS "Incidentes de Execução julgados"
     -- T954
     , '$URL/execucao/T955?MAGISTRADO=' || mag.id
           || '&DATA_OPCIONAL_FINAL=' || to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date, 'mm/dd/yyyy')
                  AS "Incidentes de execução pendentes"
FROM tb_pessoa_magistrado mag
         INNER JOIN tb_usuario_login ul
                    ON (ul.id_usuario = mag.id)
WHERE mag.id = coalesce(:MAGISTRADO, mag.id)
ORDER BY ul.ds_nome_consulta
