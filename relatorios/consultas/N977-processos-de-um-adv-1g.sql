select
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||p.nr_processo as "Processo",
        pdi.nr_documento_identificacao as "CPF",
        COALESCE(pdi.ds_nome_pessoa, ul.ds_nome) as "Nome",
        oj.ds_orgao_julgador as "Vara",
        ti.name_ as "Tarefa atual"
from
        tb_processo p
        inner join tb_processo_trf ptrf on p.id_processo = ptrf.id_processo_trf
        inner join tb_processo_parte pp on pp.id_processo_trf = ptrf.id_processo_trf
        inner join tb_usuario_login ul on pp.id_pessoa = ul.id_usuario
        inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
        left join tb_pess_doc_identificacao pdi on pdi.id_pessoa = pp.id_pessoa
        inner join tb_processo_instance pi on pi.id_processo = p.id_processo
        inner join jbpm_taskinstance ti on ti.procinst_ = pi.id_proc_inst
where 1=1
        and (COALESCE(pdi.nr_documento_identificacao ilike '%' || COALESCE(trim(:CPF), pdi.nr_documento_identificacao) || '%', true)
        or (ul.ds_login SIMILAR TO '[0-9]{11}' AND  COALESCE(ul.ds_login ilike '%' || COALESCE(replace(replace(trim(:CPF),'.',''),'-',''), ul.ds_login) || '%', true)) )
        and ul.ds_nome ilike '%' || COALESCE(:NOME_ADVOGADO, ul.ds_nome) || '%'
        and pp.in_situacao = 'A'
        and pp.id_tipo_parte = 7
        and COALESCE(pdi.in_ativo = 'S', true)
        and COALESCE(pdi.cd_tp_documento_identificacao in ('CPF'), true)
        and ((trim(:CPF) IS NOT NULL AND trim(:CPF) <> '' AND pp.id_pessoa = pdi.id_pessoa) OR (trim(:CPF) IS NULL) OR (trim(:CPF) = ''))
        and cd_processo_status = 'D'
        and ti.end_ is null
        and ((:ID_SITUACAO_PROCESSO = 2
        and not ti.name_ ilike any (array['Arquivamento Definitivo',
                                        'Arquivo definitivo',
                                        'Cartas devolvidas']))
        or (:ID_SITUACAO_PROCESSO = 3
        and ti.name_ ilike any (array['Arquivamento Definitivo',
                                        'Arquivo definitivo',
                                        'Cartas devolvidas']))
        or (:ID_SITUACAO_PROCESSO = 1))
order by oj.ds_orgao_julgador, p.nr_processo