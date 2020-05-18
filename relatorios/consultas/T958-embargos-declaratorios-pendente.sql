-- R136874 - Relatório SAO -  EMBARGOS DECLARATÓRIOS PENDENTES
-- REGRAS:
-- Ter um concluso para:
--  Conclusos os autos para julgamento/Decisão dos Embargos de Declaração a nome do Juiz
--
-- Tem algo semelhante nesse????? Antes do concluso, ter um documento do tipo:
--  - Embargos a Execucao
--  - Impugnacao a Sentenca de Liquidacao
--
-- Estar em qq fase
-- 
-- NÃO Existir um movimento dentre os seguintes, após o concluso
-- 50086 - Encerrada a conclusão
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
-- 230 - Prejudicado(s) o(s) #{nome do recurso} de #{nome da parte}  
--


WITH 
tipo_documento_embargo_declaracao AS (
    --23	Embargos de Declaração	S			49
    select id_tipo_processo_documento 
        from tb_tipo_processo_documento 
    where cd_documento = '49' 
        and in_ativo = 'S'
),
pendentes_embargos_declaratorio AS (
SELECT  concluso.id_pessoa_magistrado, 
        pen.id_processo_evento,
        pen.dt_atualizacao AS pendente_desde,
        p.id_processo,
        p.nr_processo
    FROM 
    tb_conclusao_magistrado concluso
    INNER JOIN tb_processo_evento pen 
        ON (pen.id_processo_evento = concluso.id_processo_evento 
            AND pen.id_processo_evento_excludente IS NULL
            -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
            and pen.id_evento = 51 
            -- Conclusão do tipo "Julgamento dos Embargos de Declara__o" 
            AND 
                pen.ds_texto_final_interno ilike 
                    'Conclusos os autos para%dos Embargos de Declara__o%'
            AND pen.dt_atualizacao::date <= (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
        )
    INNER JOIN tb_processo p on (p.id_processo = pen.id_processo)
    INNER JOIN LATERAL (
        SELECT doc.dt_juntada FROM tb_processo_documento doc WHERE 
        doc.id_processo = pen.id_processo
        AND doc.dt_juntada < pen.dt_atualizacao
        AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipo_documento_embargo_declaracao)
        -- nao existe movimento de julgamento entre a peticao e a conclusao
        AND NOT EXISTS(
            SELECT 1 FROM tb_processo_evento pe 
            INNER JOIN tb_evento_processual ev ON 
                (pe.id_evento = ev.id_evento_processual)
            WHERE pen.id_processo = pe.id_processo
                AND pe.id_processo_evento_excludente IS NULL
                AND pe.dt_atualizacao BETWEEN 
                    doc.dt_juntada AND pen.dt_atualizacao
                AND 
                (
                -- NÃO Existir um movimento dentre os seguintes, 
                --  entre a data de juntada da peticao e o concluso
                -- 50086 - Encerrada a conclusão
                -- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
                -- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
                -- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
                -- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
                -- 230 - Prejudicado(s) o(s) #{nome do recurso} de #{nome da parte}  
                    ev.cd_evento = '50086'
                    OR 
                    (
                        --nome do complemento bate com Embargos de Declara__o%
                        ev.cd_evento IN ('198', '871', '200', '235', '230') AND
                        pe.ds_texto_final_interno ilike '%Embargos de Declara__o%'
                    )
                    -- OR
                    -- (
                    --     ev.cd_evento = '51'AND
                    --     pe.ds_texto_final_interno ilike 
                    --         'Conclusos os autos para%dos Embargos de Declara__o%'
                    -- )
                    -- OR
                    -- ( -- houve alteração do tipo de petição
                    --     ev.cd_evento = '50088'AND
                    --     pe.ds_texto_final_interno ilike 
                    --         'Alterado o tipo de petição de Embargos de Declara__o%'
                    -- )
                )  
        )
        ORDER BY doc.dt_juntada DESC LIMIT 1
    ) peticao ON TRUE -- //ver comentario na definicao do tipo_documento_embargo_declaracao 
    WHERE
        p.id_agrupamento_fase <> 5
        AND concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
        AND NOT EXISTS(
            SELECT 1 FROM tb_processo_evento pe 
            INNER JOIN tb_evento_processual ev ON 
                (pe.id_evento = ev.id_evento_processual)
            WHERE pen.id_processo = pe.id_processo
                AND pe.id_processo_evento_excludente IS NULL
                AND pe.dt_atualizacao:: date <= (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
                AND pe.dt_atualizacao > pen.dt_atualizacao
                AND 
                (
                -- NÃO Existir um movimento dentre os seguintes, após o concluso
                -- 50086 - Encerrada a conclusão
                -- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
                -- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
                -- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
                -- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
                -- 230 - Prejudicado(s) o(s) #{nome do recurso} de #{nome da parte}  
                    ev.cd_evento = '50086'
                    OR 
                    (
                        --nome do complemento bate com Embargos de Declara__o%
                        ev.cd_evento IN ('198', '871', '200', '235', '230') AND
                        pe.ds_texto_final_interno ilike '%Embargos de Declara__o%'
                    )
                    OR
                    (
                        ev.cd_evento = '51'AND
                        pe.ds_texto_final_interno ilike 
                            'Conclusos os autos para%dos Embargos de Declara__o%'
                    )
                    OR
                    ( -- houve alteração do tipo de petição
                        ev.cd_evento = '50088'AND
                        pe.ds_texto_final_interno ilike 
                            'Alterado o tipo de petição de Embargos de Declara__o%'
                    )
                )  
        )
)
, embargos_declaratorios_pendentes AS (
    SELECT  pendentes_embargos_declaratorio.id_pessoa_magistrado, 
            COUNT(pendentes_embargos_declaratorio.id_pessoa_magistrado) AS pendentes_embargo,
            MIN(pendentes_embargos_declaratorio.pendente_desde) AS pendente_mais_antigo
    FROM pendentes_embargos_declaratorio
    GROUP BY pendentes_embargos_declaratorio.id_pessoa_magistrado
) 
SELECT 
    'TOTAL' AS "Magistrado", 
    SUM(embargos_declaratorios_pendentes.pendentes_embargo) AS "Pendentes", 
    '-' as "Ver Pendentes",
    MIN(pendente_mais_antigo) - interval '1 milliseconds' AS "ED pendente mais antigo"       
FROM embargos_declaratorios_pendentes
UNION ALL
(
    SELECT ul.ds_nome AS "Magistrado", 
    embargos_declaratorios_pendentes.pendentes_embargo AS "Pendentes",
    '$URL/execucao/T959?MAGISTRADO='||embargos_declaratorios_pendentes.id_pessoa_magistrado
    ||'&DATA_OPCIONAL_FINAL='||to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date,'mm/dd/yyyy')
    ||'&texto='||embargos_declaratorios_pendentes.pendentes_embargo as "Ver Pendentes",
    embargos_declaratorios_pendentes.pendente_mais_antigo AS "ED pendente mais antigo"
    FROM embargos_declaratorios_pendentes  
    INNER JOIN tb_usuario_login ul ON (ul.id_usuario = embargos_declaratorios_pendentes.id_pessoa_magistrado)
    ORDER BY ul.ds_nome
)
