with arquivados_definitivamente as (
   select
      p.id_processo,
      p.nr_processo,
      ti.start_ dt_arquivamento,
      oj.ds_orgao_julgador
   from
      tb_processo p
   join
      tb_processo_trf ptrf on (p.id_processo = ptrf.id_processo_trf)
   join
      tb_processo_instance procxins on (p.id_processo = procxins.id_processo)
   join
      jbpm_taskinstance ti on (procxins.id_proc_inst = ti.procinst_ and ti.end_ is null and ti.isopen_ = 'true')
   join
      tb_orgao_julgador oj on (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
   where
      --Processo deve estar arquivado RN02 e RN03
      ti.name_ in ('Arquivo definitivo', 'Arquivamento Definitivo')
      and ti.start_ is not null
      and ptrf.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, ptrf.id_orgao_julgador) --Incluir o parâmetro de filtro OJ
)
select
   'http://processo='||ad.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
   'http://processo='||ad.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||ad.nr_processo as "Processo",
   ad.ds_orgao_julgador as "Órgão Julgador" ,
   to_char(ad.dt_arquivamento, 'dd/mm/yyyy') as "Data do Arquivamento"
from
   arquivados_definitivamente ad
where
   -- RN01 - processo deve ter iniciado a execução / Processos da CLE são consideradosde acordo com a sua natureza
   (exists (
      select 1
      from
         tb_processo_clet pclet
      join
         tb_natureza_clet nclet using (id_natureza_clet)
      where
         nclet.tp_natureza = 'E'
         and pclet.id_processo_trf = ad.id_processo
   )
   or exists (
      select 1
      from
         tb_processo_evento prev
      join
         tb_evento_processual ev on (prev.id_evento = ev.id_evento_processual)
      where
         ev.cd_evento = '11385'
         and prev.id_processo_evento_excludente is null
         and prev.id_processo = ad.id_processo
         and prev.dt_atualizacao < ad.dt_arquivamento
   ))
   -- RN04 - O processo não deve ter a movimentação de extinção da execução em data anterior ao arquivamento definitivo
   and not exists  (
      select 1
      from
         tb_processo_evento prev
      join
         tb_evento_processual ev on (prev.id_evento = ev.id_evento_processual)
      where
         ev.cd_evento = '196'
         and prev.id_processo_evento_excludente is null
         and prev.id_processo = ad.id_processo
         and prev.dt_atualizacao < ad.dt_arquivamento
   )
order by ad.ds_orgao_julgador, ad.nr_processo