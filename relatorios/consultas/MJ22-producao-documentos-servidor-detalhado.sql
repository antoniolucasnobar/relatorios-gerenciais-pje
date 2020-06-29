WITH documentos_incluidos_usuario AS (
	select pd.id_usuario_inclusao as id_usuario
	     , pd.ds_processo_documento AS nome_documento
	     , pd.dt_inclusao AS data
	     , 'Inclusão' as tipo_operacao
	from tb_processo_documento pd
		inner join tb_processo_trf ptrf on ptrf.id_processo_trf = pd.id_processo
        INNER JOIN tb_orgao_julgador oj ON (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
        inner join tb_pessoa_servidor ps on ps.id = pd.id_usuario_inclusao
	where oj.id_orgao_julgador = COALESCE(:ORGAO_JULGADOR, oj.id_orgao_julgador)
	  AND pd.dt_inclusao::date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
	  AND ptrf.cd_processo_status = 'D'
      AND 2 = COALESCE(:INCLUSAO_ASSINATURA_DOCUMENTO, 2)

)
, documentos_assinados_usuario AS (
    select pdbpa.id_pessoa as id_usuario
         , pd.ds_processo_documento AS nome_documento
         , pdbpa.dt_assinatura AS data
         , 'Assinatura' as tipo_operacao
    from tb_processo_documento pd
             inner join tb_proc_doc_bin_pess_assin pdbpa on pdbpa.id_processo_documento_bin = pd.id_processo_documento_bin
             inner join tb_processo_trf ptrf on ptrf.id_processo_trf = pd.id_processo
             INNER JOIN tb_orgao_julgador oj ON (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
             inner join tb_pessoa_servidor ps on ps.id = pdbpa.id_pessoa
    where oj.id_orgao_julgador = COALESCE(:ORGAO_JULGADOR, oj.id_orgao_julgador)
      AND pdbpa.dt_assinatura::date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
      AND ptrf.cd_processo_status = 'D'
      AND 1 = COALESCE(:INCLUSAO_ASSINATURA_DOCUMENTO, 1)
)

select ul.ds_nome as "Nome"
    , t.nome_documento AS "Documento"
    , t.data AS  "Data"
    , t.tipo_operacao AS "Tipo de Operação"
from (
    SELECT * FROM documentos_incluidos_usuario
	union
    SELECT * FROM documentos_assinados_usuario
) as t
	inner join tb_usuario_login ul on ul.id_usuario = t.id_usuario
    WHERE ul.id_usuario = COALESCE(:SERVIDOR, ul.id_usuario)

order by ul.ds_nome, t.data

