-- [R136877][T955] - Relatório SAO - INCIDENTES DE EXECUÇÃO PENDENTES
-- REGRAS NO T954

WITH tipos_documento AS (
    --16	Embargos à Execução	S			7143
    --32	Impugnação à Sentença de Liquidação	S			53
    select id_tipo_processo_documento, ds_tipo_processo_documento
        from tb_tipo_processo_documento 
    where cd_documento IN ('53', '7143') 
        and in_ativo = 'S'
) ,
pendentes_execucao AS (
SELECT  concluso.id_pessoa_magistrado, 
        pen.id_processo_evento,
        to_char(pen.dt_atualizacao, 'dd/mm/yy') AS pendente_desde,
        pen.ds_texto_final_interno AS nome_concluso,
        p.id_processo,
        p.nr_processo,
        to_char(peticao.dt_juntada, 'dd/mm/yy') AS juntada_peticao,
        peticao.ds_tipo_processo_documento AS tipo_peticao
        -- COUNT(concluso.id_pessoa_magistrado) AS total
    FROM 
    tb_conclusao_magistrado concluso
    INNER JOIN tb_processo_evento pen 
        ON (pen.id_processo_evento = concluso.id_processo_evento 
            AND pen.id_processo_evento_excludente IS NULL
            -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
            and pen.id_evento = 51 
            -- Conclusão do tipo "Julgamento da ação incidental" 
            AND (
                pen.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da ação incidental na execu__o%'
                OR pen.ds_texto_final_interno ilike 'Conclusos os autos para julgamento dos Embargos _ Execu__o%'
                OR pen.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da Impugna__o _ Sentença de Liquida__o%'
                )
        )
    INNER JOIN tb_processo p on (p.id_processo = pen.id_processo)
    LEFT JOIN LATERAL (
        SELECT doc.dt_juntada, tipo.ds_tipo_processo_documento 
        FROM tb_processo_documento doc 
        INNER JOIN tipos_documento tipo ON 
            (doc.id_tipo_processo_documento = tipo.id_tipo_processo_documento)
        WHERE 
            doc.id_processo = pen.id_processo
            AND doc.dt_juntada < pen.dt_atualizacao
            -- AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipos_documento)
        ORDER BY doc.dt_juntada DESC LIMIT 1
    ) peticao ON TRUE
    WHERE
        concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
        -- concluso.in_diligencia != 'S'
        AND p.id_agrupamento_fase = 4 -- somente execucao --
        AND NOT EXISTS(
            SELECT 1 FROM tb_processo_evento pe 
            INNER JOIN tb_evento_processual ev ON 
                (pe.id_evento = ev.id_evento_processual)
            WHERE pen.id_processo = pe.id_processo
            AND pe.id_processo_evento_excludente IS NULL
            AND (pe.dt_atualizacao > pen.dt_atualizacao
                    -- OR
                    -- pe.dt_atualizacao BETWEEN peticao.dt_juntada AND pen.dt_atualizacao
                )
            AND (
                (
                    -- eh movimento de julgamento
-- 50086 - Encerrada a conclusão  
-- 219   - Julgado(s) procedente(s) o(s) pedido(s) (#{classe processual}/ #{nome do incidente}) de #{nome da parte}
-- 221   - Julgado(s) procedente(s) em parte o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}  
-- 220   - Julgado(s) improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
-- 50013 - Julgado(s) liminarmente improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}  
-- 50050 - Extinto com resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
-- 50048 - Extinto sem resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
-- 50087 - Baixado o incidente/ recurso (#{nome do incidente} / #{nome do recurso}) sem decisão, onde nome do recurso deve corresponder a Embargos à Execução ou Impugnação à Sentença de Liquidação 
-- 50049 - Prejudicado o incidente #{nome do incidente} de #{nome da parte}
                    ev.cd_evento IN 
                    ('50086', '219', '221', '220', '50013', '50050', '50048')
                    OR 
                    (
                        --nome do complemento bate com o da conclusao
                        ev.cd_evento = '50087' AND
                        (pen.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%' and pe.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%')
                        OR (pen.ds_texto_final_interno ilike '%Embargos à Execução%' and pe.ds_texto_final_interno ilike '%Embargos à Execução%')
                        OR (pen.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da ação incidental na execu__o%' 
                            and (pe.ds_texto_final_interno ilike '%Embargos à Execução%' 
                                OR pe.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%'
                            )
                        )
                    )
-- 50049 - Prejudicado o incidente #{nome do incidente} de #{nome da parte}
                    OR 
                    (
                        --nome do complemento bate com o da conclusao
                        ev.cd_evento = '50049' AND
                        pe.ds_texto_final_interno ilike ANY 
                            (ARRAY['Prejudicado o incidente Impugnação à Sentença de Liquidação%', 
		                           'Prejudicado o incidente Embargos à Execução%']
                            ) 
                    )
                )
            ) 
        )
)
 SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
        ||cj.ds_classe_judicial_sigla||' '
        ||p.nr_processo as "Processo",
ul.ds_nome AS "Magistrado",
p.tipo_peticao
--||' - '|| p.juntada_peticao 
AS "Tipo Petição",
p.juntada_peticao AS "Data Petição",
REGEXP_REPLACE(p.nome_concluso,
'Conclusos os autos para julgamento (da|dos) (.*) a (.*)'
,'\2') AS "Conclusos os autos para julgamento",
p.pendente_desde AS "Pendente Desde",
pt.nm_tarefa as "Tarefa Atual",
(select COALESCE(string_agg(prioridade.ds_prioridade::character varying, ', '), '-')
    from 
    tb_proc_prioridde_processo tabela_ligacao 
    inner join tb_prioridade_processo prioridade 
        on (tabela_ligacao.id_prioridade_processo = prioridade.id_prioridade_processo)
    where 
    tabela_ligacao.id_processo_trf = p.id_processo
) AS "Prioridades"
FROM pendentes_execucao p
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = p.id_pessoa_magistrado)
inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
ORDER BY ul.ds_nome, p.pendente_desde


