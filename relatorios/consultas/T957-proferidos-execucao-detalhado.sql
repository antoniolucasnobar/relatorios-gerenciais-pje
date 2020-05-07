-- R136878 - Relatório SAO - INCIDENTES DE EXECUCAO Julgados

-- explain analyze

WITH tipos_documento AS (
    --16	Embargos à Execução	S			7143
    --32	Impugnação à Sentença de Liquidação	S			53
    select id_tipo_processo_documento 
        from tb_tipo_processo_documento 
    where cd_documento = '7007' 
        and in_ativo = 'S'
),
tipos_movimento AS (
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
 proferidas AS (
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
                SELECT id_tipo_processo_documento FROM tipos_documento
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
                SELECT id_evento_processual FROM tipos_movimento
            )
            AND date(doc.dt_juntada) = date(pen.dt_atualizacao)
            AND  pen.ds_texto_final_interno ilike ANY (
                            ARRAY['%Impugnação à Sentença de Liquidação%', 
		                           '%Embargos à Execução%']
            ) 
    )

)
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
         'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
         ||cj.ds_classe_judicial_sigla||' '
         ||p.nr_processo as "Processo",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade",
    ul.ds_nome AS "Magistrado",
    proferidas.dt_juntada AS "Proferida em"
    -- ,
--    proferidas.dt_atualizacao as "Inicio Execução"
FROM proferidas 
    INNER JOIN tb_usuario_login ul on (ul.id_usuario = proferidas.id_pessoa)
    INNER JOIN tb_processo p ON (p.id_processo = proferidas.id_processo)
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
    inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
ORDER BY ul.ds_nome, proferidas.dt_juntada
