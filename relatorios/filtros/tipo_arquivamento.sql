-- permite filtrar se quer arquivo definitivo ou provisorio
SELECT p.* FROM tb_processo p
    WHERE
          p.nr_processo = '0021381-58.2015.5.04.0016'
         AND
          CASE (
              select ev.cd_evento
              from
                  tb_processo_evento prev
                      join
                  tb_evento_processual ev on (prev.id_evento = ev.id_evento_processual)
              where
                    -- 246 - definitvamente, 245 -- provisoriamente
                    -- 893 - desarquivados os autos
                ev.cd_evento IN ('246', '245', '893')
                and prev.id_processo_evento_excludente is null
                and prev.id_processo = p.id_processo
              ORDER BY prev.dt_atualizacao DESC
              LIMIT 1
          )
              WHEN '245' THEN FALSE
              WHEN '246' THEN FALSE
          ELSE  TRUE
        END
limit 12
