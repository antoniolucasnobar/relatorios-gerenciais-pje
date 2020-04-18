SELECT
    'http://processo='||bndt.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
    'http://processo='||bndt.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||bndt.nr_processo as "Processo",
    bndt.ds_orgao_julgador as "Órgão Julgador",
    (
        select name_ from
                jbpm_taskinstance
        where
                procinst_ in (select pi.id_proc_inst from tb_processo_instance pi where pi.id_processo = bndt.id_processo)
                and end_ is null and isopen_ = 'true'
        order by start_ desc
        limit 1
    ) as "Tarefa"
FROM
     (SELECT
          proc.id_processo,
          proc.nr_processo,
          oj.ds_orgao_julgador
      FROM
          tb_processo proc
          join tb_processo_trf ptrf on proc.id_processo = ptrf.id_processo_trf
          join tb_orgao_julgador oj on (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
      WHERE
          proc.id_agrupamento_fase = 5
      -- A partir daqui, filtros possíveis e opcionais
        and oj.id_orgao_julgador = coalesce (:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
        AND
            -- verifica se o usuario quer com ou sem registro no BNDT
            (TRUE =
                (case
                  WHEN (1 = :REGISTRO_BNDT)
                      THEN EXISTS(
                          SELECT 1 FROM tb_debito_trabalhista dt
                                    INNER JOIN tb_processo_parte pp ON
                                        (dt.id_processo_parte = pp.id_processo_parte)
--                                     join tb_dbto_trblhsta_historico dth on
--                                         (dth.id_processo_parte = pp.id_processo_parte)
                          WHERE
                              proc.id_processo = pp.id_processo_trf
                            -- não considera os débitos excluídos
                            AND dt.id_situacao_debito_trabalhista <> 4
--                             and dth.cd_erro_bndt is null
                      )
                  WHEN (0 = :REGISTRO_BNDT)
                      THEN
                      NOT EXISTS(
                              SELECT 1 FROM tb_debito_trabalhista dt
                                                INNER JOIN tb_processo_parte pp ON
                                  (dt.id_processo_parte = pp.id_processo_parte)
--                                                 join tb_dbto_trblhsta_historico dth on
--                                   (dth.id_processo_parte = pp.id_processo_parte)
                              WHERE
                                      proc.id_processo = pp.id_processo_trf
                                -- não considera os débitos excluídos
                                AND dt.id_situacao_debito_trabalhista <> 4
--                                 and dth.cd_erro_bndt is null
                          )
                 ELSE FALSE
                 END
                 )
            )
        -- escolhe se quer apenas os arquivados definitivamente ou provisoriamente
         AND  (
              select ev.cd_evento = :TIPO_ARQUIVAMENTO 
              from
                  tb_processo_evento prev
                      join
                  tb_evento_processual ev on (prev.id_evento = ev.id_evento_processual)
              where
                    -- 246 - definitvamente, 245 -- provisoriamente
                    -- 893 - desarquivados os autos
                ev.cd_evento IN ('246', '245', '893')
                and prev.id_processo_evento_excludente is null
                and prev.id_processo = proc.id_processo
              ORDER BY prev.dt_atualizacao DESC
              LIMIT 1
          )
     ) bndt
    order by bndt.nr_processo