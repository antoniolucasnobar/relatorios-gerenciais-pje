-- R136878 - Relatório SAO - INCIDENTES DE EXECUCAO Julgados

-- explain analyze

WITH tipos_doc_embargos_exec_impug_sentenca_liq AS (
    --16	Embargos à Execução	S			7143
    --32	Impugnação à Sentença de Liquidação	S			53
    select id_tipo_processo_documento 
        from tb_tipo_processo_documento 
    where cd_documento = '7007' 
        and in_ativo = 'S'
),
movimentos_julgado_incidentes_execucao AS (
    SELECT ev.id_evento_processual 
    FROM tb_evento_processual ev 
    WHERE 
                    -- eh movimento de julgamento
-- 219   - Julgado(s) procedente(s) o(s) pedido(s) (#{classe processual}/ #{nome do incidente}) de #{nome da parte}
-- 221   - Julgado(s) procedente(s) em parte o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}  
-- 220   - Julgado(s) improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
-- 50013 - Julgado(s) liminarmente improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}  
-- 50050 - Extinto com resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
-- 50048 - Extinto sem resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
        ev.cd_evento IN 
        ('219', '221', '220', '50013', '50050', '50048')
) 
,
 incidentes_execucao_julgados AS (
    select 
    -- ul.ds_nome, 
    assin.id_pessoa, 
    doc.dt_juntada,
    doc.id_processo,
    iniciada_execucao.dt_atualizacao
    from tb_processo_documento doc 
    inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
    INNER JOIN tb_processo_evento iniciada_execucao 
        ON (iniciada_execucao.id_processo = doc.id_processo 
            AND iniciada_execucao.id_evento = 11385)
    where doc.in_ativo = 'S'
    -- 62
    AND doc.id_tipo_processo_documento =  (
                SELECT id_tipo_processo_documento FROM tipos_doc_embargos_exec_impug_sentenca_liq
            )
    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    -- and tipo.cd_documento = '7007'
    -- so pega documentos juntados depois do inicio da execucao
    and doc.dt_juntada between GREATEST(iniciada_execucao.dt_atualizacao, :DATA_INICIAL) and (:DATA_FINAL)
    AND EXISTS (
        SELECT 1 FROM 
            tb_processo_evento pen 
        WHERE 
            pen.id_processo = doc.id_processo 
            AND pen.id_processo_evento_excludente IS NULL
            and pen.id_evento IN (
                SELECT id_evento_processual FROM movimentos_julgado_incidentes_execucao
            )
            AND date(doc.dt_juntada) = date(pen.dt_atualizacao)
            AND  pen.ds_texto_final_interno ilike ANY (
                            ARRAY['%Impugnação à Sentença de Liquidação%', 
		                           '%Embargos à Execução%']
            ) 
    )

)
SELECT ul.ds_nome AS "Magistrado", 
-- julgados_por_magistrado.total,
    incidentes_execucao_julgados_por_magistrado.julgados_execucao AS "Proferidas"
    ,
    '$URL/execucao/T957?MAGISTRADO='||incidentes_execucao_julgados_por_magistrado.id_pessoa
    ||'&DATA_INICIAL='||to_char(:DATA_INICIAL::date,'mm/dd/yyyy')
    ||'&DATA_FINAL='||to_char(:DATA_FINAL::date,'mm/dd/yyyy')
    ||'&texto='||incidentes_execucao_julgados_por_magistrado.julgados_execucao as "Ver Proferidas"
FROM  (
    SELECT  incidentes_execucao_julgados.id_pessoa,
        COUNT(incidentes_execucao_julgados.id_pessoa) AS julgados_execucao
    FROM incidentes_execucao_julgados
    GROUP BY incidentes_execucao_julgados.id_pessoa
) incidentes_execucao_julgados_por_magistrado
    INNER JOIN tb_usuario_login ul on (ul.id_usuario = incidentes_execucao_julgados_por_magistrado.id_pessoa)
ORDER BY ul.ds_nome
