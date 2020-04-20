select 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
       'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||cj.ds_classe_judicial_sigla||' '||p.nr_processo as "Processo", --  oj.ds_orgao_julgador as "Unidade",
 --  cj.ds_classe_judicial,

  (SELECT oj.ds_orgao_julgador
   FROM tb_orgao_julgador oj
   WHERE oj.id_orgao_julgador = desloc.id_oj_origem) as "Órgão Julgador",

  (SELECT oj.ds_orgao_julgador
   FROM tb_orgao_julgador oj
   WHERE oj.id_orgao_julgador = desloc.id_oj_destino) as "Posto",
 to_char(desloc.dt_deslocamento, 'dd/mm/yyyy hh24:mi') as "Data envio ao Posto",
 to_char(desloc.dt_retorno, 'dd/mm/yyyy hh24:mi') as "Data Retorno do Posto",
 fase.nm_agrupamento_fase as "Fase",
 t.ds_tarefa as "Tarefa"
from tb_processo p
join tb_processo_trf ptrf on p.id_processo = ptrf.id_processo_trf
INNER JOIN pje.tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
LEFT JOIN tb_hist_desloca_oj desloc ON p.id_processo::integer = desloc.id_processo_trf
inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
join tb_orgao_julgador oj on (ptrf.id_orgao_julgador = oj.id_orgao_julgador)
join tb_processo_instance procxins on (p.id_processo = procxins.id_processo)--RN01
join jbpm_taskinstance ti on (procxins.id_proc_inst = ti.procinst_
                              and ti.end_ is null
                              and ti.isopen_ = 'true')
join tb_tarefa_jbpm tj on (tj.id_jbpm_task = ti.task_)
join tb_tarefa t on (tj.id_tarefa = t.id_tarefa)
where -- ds_texto_final_externo ILIKE 'Remetidos os autos para%CEJUSC%' and
 desloc.id_oj_origem = coalesce(:ORGAO_JULGADOR_TODOS,desloc.id_oj_origem)
  AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
  AND desloc.dt_deslocamento :: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
  AND desloc.dt_retorno IS NULL
order by desloc.dt_deslocamento :: date