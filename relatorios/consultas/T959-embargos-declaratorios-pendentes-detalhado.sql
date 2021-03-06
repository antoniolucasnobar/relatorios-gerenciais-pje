-- [R136874][T959] - Relatório SAO -  EMBARGOS DECLARATÓRIOS PENDENTES detalhado
-- REGRAS no T958

-- explain analyze

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
                -- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
                -- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
                -- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
                -- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
                -- 230 - Prejudicado(s) o(s) #{nome do recurso} de #{nome da parte}  
                    (
                        --nome do complemento bate com Embargos de Declara__o%
                        ev.cd_evento IN ('198', '871', '200', '235', '230') AND
                        pe.ds_texto_final_interno ilike '%Embargos de Declara__o%'
                    )
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
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
         'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
         ||cj.ds_classe_judicial_sigla||' '
         ||p.nr_processo as "Processo",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade",
    ul.ds_nome AS "Magistrado",
    pendentes_embargos_declaratorio.pendente_desde AS "Pendente desde",
    pt.nm_tarefa as "Tarefa Atual",
    (select COALESCE(string_agg(prioridade.ds_prioridade::character varying, ', '), '-')
        from 
        tb_proc_prioridde_processo tabela_ligacao 
        inner join tb_prioridade_processo prioridade 
            on (tabela_ligacao.id_prioridade_processo = prioridade.id_prioridade_processo)
        where 
        tabela_ligacao.id_processo_trf = p.id_processo
    ) AS "Prioridades"
FROM pendentes_embargos_declaratorio 
    INNER JOIN tb_usuario_login ul on (ul.id_usuario = pendentes_embargos_declaratorio.id_pessoa_magistrado)
    INNER JOIN tb_processo p ON (p.id_processo = pendentes_embargos_declaratorio.id_processo)
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
    inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
ORDER BY ul.ds_nome, pendentes_embargos_declaratorio.pendente_desde
