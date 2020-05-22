-- [R136875][T963] - EMBARGOS DECLARATÓRIOS JULGADOS
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
WITH
tipo_documento_embargo_declaracao AS (
    --23	Embargos de Declaração	S			49
    select id_tipo_processo_documento 
        from tb_tipo_processo_documento 
    where cd_documento = '49' 
        and in_ativo = 'S'
),
tipo_documento_sentenca AS (
    --62	Sentença	S			7007
    select id_tipo_processo_documento 
        from tb_tipo_processo_documento 
    where cd_documento = '7007' 
        and in_ativo = 'S'
),
movimentos_embargos_declaracao_julgados AS (
    SELECT ev.id_evento_processual 
    FROM tb_evento_processual ev 
    WHERE 
    -- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
    -- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
    -- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
    -- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
        ev.cd_evento IN 
        ('198', '871', '200', '235')
) 
,
embargos_declaracao_julgados AS (
    select 
    assin.id_pessoa, 
    doc.dt_juntada,
    doc.id_processo,
    movimento_julgamento_ed.ds_texto_final_interno
    from tb_processo_documento doc 
    inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
    inner join lateral (
        select pen.ds_texto_final_interno, pen.dt_atualizacao FROM 
        tb_conclusao_magistrado concluso
        INNER JOIN tb_processo_evento pen 
            ON (pen.id_processo_evento = concluso.id_processo_evento 
                and pen.id_processo = doc.id_processo 
                AND pen.id_processo_evento_excludente IS NULL
                and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                -- AND pen.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
            )
        where pen.dt_atualizacao < doc.dt_juntada 
        order by pen.dt_atualizacao desc 
        limit 1
    ) concluso ON TRUE
    INNER JOIN LATERAL (
        SELECT COUNT(*) AS qtd
        FROM tb_processo_evento juntada
        WHERE
            juntada.id_processo = doc.id_processo
            AND juntada.id_processo_evento_excludente IS NULL
            AND juntada.dt_atualizacao < doc.dt_juntada
            AND (
                (juntada.id_evento = 85
                AND juntada.ds_texto_final_externo
                      ilike 'Juntada a peti__o de Embargos de Declara__o'
                     )
            OR
                 (juntada.id_evento = 50088
                     AND juntada.ds_texto_final_externo
                      ilike 'Alterado o tipo de peti__o de % para Embargos de Declara__o'
                     )
            )
    ) juntadas ON TRUE
    INNER JOIN LATERAL (
        SELECT COUNT(*) AS qtd
        FROM tb_processo_evento julgamento
        WHERE
            julgamento.id_processo = doc.id_processo
            AND julgamento.id_processo_evento_excludente IS NULL
            AND julgamento.id_processo_documento IS DISTINCT FROM doc.id_processo_documento
            AND julgamento.dt_atualizacao < doc.dt_juntada  - ('5 minutes')::interval
            AND
              (
                  (julgamento.ds_texto_final_interno ilike '%Embargos de Declara__o%'
                      AND julgamento.id_evento IN
                          (
                              SELECT id_evento_processual
                              FROM movimentos_embargos_declaracao_julgados
                          )
                  )
                  OR
                  (juntada.id_evento = 50088
                      AND juntada.ds_texto_final_externo
                       ilike 'Alterado o tipo de peti__o de Embargos de Declara__o%'
                      )
              )
    ) julgamentos_anteriores ON TRUE
    INNER JOIN LATERAL (
        SELECT peti.dt_juntada AS data_peticao FROM tb_processo_documento peti WHERE
        peti.id_processo = doc.id_processo
        AND peti.dt_juntada < concluso.dt_atualizacao
        AND peti.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipo_documento_embargo_declaracao)
        -- nao existe movimento de julgamento entre a peticao e a conclusao
        AND NOT EXISTS(
            SELECT 1 FROM tb_processo_evento pe 
            INNER JOIN tb_evento_processual ev ON 
                (pe.id_evento = ev.id_evento_processual)
            WHERE doc.id_processo = pe.id_processo
                AND pe.id_processo_evento_excludente IS NULL
                AND pe.dt_atualizacao BETWEEN 
                    peti.dt_juntada AND concluso.dt_atualizacao
                AND 
                (
                -- NÃO Existir um movimento dentre os seguintes, 
                --  entre a data de juntada da peticao e o concluso
                -- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
                -- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
                -- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
                -- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
                    (
                        --nome do complemento bate com Embargos de Declara__o%
                        ev.cd_evento IN ('198', '871', '200', '235') AND
                        pe.ds_texto_final_interno ilike '%Embargos de Declara__o%'
                    )
                )  
        )
        ORDER BY peti.dt_juntada DESC LIMIT 1
    ) peticao ON TRUE
    INNER JOIN LATERAL (
        SELECT pen.ds_texto_final_interno FROM 
            tb_processo_evento pen 
        WHERE 
            pen.id_processo = doc.id_processo 
            AND pen.id_processo_evento_excludente IS NULL
            and pen.id_evento IN (
                SELECT id_evento_processual FROM movimentos_embargos_declaracao_julgados
            )
            AND date(doc.dt_juntada) <= date(pen.dt_atualizacao)
            AND  pen.ds_texto_final_interno ilike '%Embargos de Declara__o%' 
    ) movimento_julgamento_ed ON TRUE
    where doc.in_ativo = 'S'
    AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipo_documento_sentenca)
    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    and doc.dt_juntada :: date between coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
    and concluso.ds_texto_final_interno ilike 'Conclusos os autos para % dos Embargos de Declara__o%'
)
, embargo_declaracao_julgado AS (
    SELECT  embargos_declaracao_julgados.id_pessoa, 
        COUNT(embargos_declaracao_julgados.id_pessoa) AS quantidade_julgado
    FROM embargos_declaracao_julgados
    GROUP BY embargos_declaracao_julgados.id_pessoa
)
SELECT 
    'TOTAL' AS "Magistrado", 
    SUM(embargo_declaracao_julgado.quantidade_julgado) AS "EDs Julgados", 
    '-' as "Ver EDs Julgados"
FROM embargo_declaracao_julgado
UNION ALL
(
    SELECT ul.ds_nome AS "Magistrado", 
        embargo_declaracao_julgado.quantidade_julgado AS "EDs Julgados"
        ,
        '$URL/execucao/T961?MAGISTRADO='||embargo_declaracao_julgado.id_pessoa
        ||'&DATA_INICIAL_OPCIONAL='||to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date,'mm/dd/yyyy')
        ||'&DATA_OPCIONAL_FINAL='||to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date,'mm/dd/yyyy')
        ||'&texto='||embargo_declaracao_julgado.quantidade_julgado as "Ver EDs Julgados"
    FROM embargo_declaracao_julgado  
    INNER JOIN tb_usuario_login ul ON (ul.id_usuario = embargo_declaracao_julgado.id_pessoa)
    ORDER BY ul.ds_nome
) 

