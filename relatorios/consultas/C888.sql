select
                      'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
                      'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||p.nr_processo as "Processo",
                      oj.ds_orgao_julgador as "Vara",
                      t.ds_tarefa as "Tarefa",
                      fase.nm_agrupamento_fase as "Fase",
                      --RN02
                      date_part('day', current_date - coalesce(ti.start_, ti.create_))::integer as "Dias"
                   from
                      tb_processo p
                   join
                      tb_processo_trf ptrf on (p.id_processo = ptrf.id_processo_trf)
                inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)

                   join
                      tb_orgao_julgador oj on (ptrf.id_orgao_julgador = oj.id_orgao_julgador)
                   join
                      tb_processo_instance procxins on (p.id_processo = procxins.id_processo)
                   --RN01
                   join
                      jbpm_taskinstance ti on (procxins.id_proc_inst = ti.procinst_ and ti.end_ is null and ti.isopen_ = 'true')
                   join
                      tb_tarefa_jbpm tj on (tj.id_jbpm_task = ti.task_)
                   join tb_tarefa t on (tj.id_tarefa = t.id_tarefa)
                   --RN03
                   where not ti.name_ ilike any (array['Aguardando apreciação pela instância superior%',
                                                       'Aguardando cumprimento de acordo%',
                                                       'Aguardando cumprimento de acordo ou pagamentos',
                                                       'Aguardando final do sobrestamento',
                                                       'Aguardando pgto RPV Precatório',
                                                       'Arquivamento Provisório',
                                                       'Arquivamento Definitivo',
                                                       'Arquivo provisório',
                                                       'Arquivo definitivo',                                                       
                                                       'Arquivo',
                                                       'Acordo',
                                                       'Cartas devolvidas'])
                      and not (
                        ti.name_ ilike any (array['Aguardando audiência%'])
                        and exists (
                                (
                                SELECT 1
                                  FROM tb_processo_audiencia pa2
                                 WHERE pa2.id_processo_trf = ptrf.id_processo_trf
                                   AND pa2.cd_status_audiencia = 'M' and pa2.in_ativo = 'S'
                                )
                        )
                      )
                      AND oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS,oj.id_orgao_julgador)
                      AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
                      AND fase.id_agrupamento_fase != 5
                      and date_part('day', current_date - coalesce(ti.start_, ti.create_))::integer >= coalesce(:DIAS,date_part('day', current_date - coalesce(ti.start_, ti.create_))::integer)