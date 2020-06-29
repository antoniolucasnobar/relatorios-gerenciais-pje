-- [R?][MJ02]
select ul.ds_nome as "nome", sum(t.inclusao) as "documentos incluídos", sum(t.assinatura) as "documentos assinados"
from (
         select pd.id_usuario_inclusao as id_usuario, count(*) as inclusao, 0 as assinatura
         from tb_processo_documento pd
                  inner join tb_processo_trf ptrf on ptrf.id_processo_trf = pd.id_processo
                  inner join tb_pessoa_servidor ps on ps.id = pd.id_usuario_inclusao
         where ptrf.id_orgao_julgador = coalesce(:ORGAO_JULGADOR, ptrf.id_orgao_julgador)
           and pd.dt_inclusao::date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
           and ptrf.cd_processo_status = ''D''
         group by pd.id_usuario_inclusao
         union
         select pdbpa.id_pessoa as id_usuario, 0 as inclusao, count(*) as assinatura
         from tb_processo_documento pd
             inner join tb_proc_doc_bin_pess_assin pdbpa
         on pdbpa.id_processo_documento_bin = pd.id_processo_documento_bin
             inner join tb_processo_trf ptrf on ptrf.id_processo_trf = pd.id_processo
             inner join tb_pessoa_servidor ps on ps.id = pdbpa.id_pessoa
         where ptrf.id_orgao_julgador = coalesce (:ORGAO_JULGADOR
             , ptrf.id_orgao_julgador)
           and pdbpa.dt_assinatura::date between (:DATA_INICIAL)::date
           and (:DATA_FINAL)::date
           and ptrf.cd_processo_status = '' D ''
         group by pdbpa.id_pessoa
     ) as t
         inner join tb_usuario_login ul on ul.id_usuario = t.id_usuario
group by ul.ds_nome, ul.ds_login
order by nome
