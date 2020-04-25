-- #Título
-- Arquivados com ou sem registro no BNDT

-- #Código
-- T996

-- #Nome no menu
-- Arquivados com ou sem registro no BNDT

-- #Menu superior
-- Vara

-- #Glossário
-- Lista os processos arquivados (arquivo definitivo ou provisório) com ou sem registro no BNDT. Não são considerados os registros excluídos do BNDT.
-- <br />
-- No campo tipo de arquivamento deixa só definitivo e provisório
-- Registro no BNDT não precisa interrogação
SELECT
    'http://processo='||proc.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
    'http://processo='||proc.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||proc.nr_processo as "Processo",
    oj.ds_orgao_julgador as "Órgão Julgador",

    (
        select prev.dt_atualizacao
        from
            tb_processo_evento prev
                join
            tb_evento_processual ev on (prev.id_evento = ev.id_evento_processual)
        where
            -- 246 - definitvamente, 245 -- provisoriamente
            -- 893 - desarquivados os autos
        ev.cd_evento = :TIPO_ARQUIVAMENTO
        and prev.id_processo_evento_excludente is null
        and prev.id_processo = proc.id_processo
        ORDER BY prev.dt_atualizacao DESC
        LIMIT 1
    ) AS "Data do Arquivamento",

    ptar.nm_tarefa as "Tarefa"

      FROM
          tb_processo proc
          join tb_processo_trf ptrf on proc.id_processo = ptrf.id_processo_trf
          join tb_orgao_julgador oj on (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
          join tb_processo_tarefa ptar on (proc.id_processo = ptar.id_processo_trf)
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
                          WHERE
                              proc.id_processo = pp.id_processo_trf
                            -- não considera os débitos excluídos
                            AND dt.id_situacao_debito_trabalhista <> 4
                      )
                  WHEN (0 = :REGISTRO_BNDT)
                      THEN
                      NOT EXISTS(
                              SELECT 1 FROM tb_debito_trabalhista dt
                                                INNER JOIN tb_processo_parte pp ON
                                  (dt.id_processo_parte = pp.id_processo_parte)
                              WHERE
                                      proc.id_processo = pp.id_processo_trf
                                -- não considera os débitos excluídos
                                AND dt.id_situacao_debito_trabalhista <> 4
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
        -- filtro de data
          AND EXISTS
          
          ( SELECT 1 FROM (
              select prev.dt_atualizacao
              from
                  tb_processo_evento prev
                      join
                  tb_evento_processual ev on (prev.id_evento = ev.id_evento_processual)
              where
                    -- 246 - definitvamente, 245 -- provisoriamente
                    -- 893 - desarquivados os autos
                ev.cd_evento = :TIPO_ARQUIVAMENTO 
                and prev.id_processo_evento_excludente is null
                and prev.id_processo = proc.id_processo
              ORDER BY prev.dt_atualizacao DESC
              LIMIT 1
            ) dataUltimoMovimento
            WHERE dataUltimoMovimento.dt_atualizacao :: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date 
          )         
    
    order by proc.nr_processo