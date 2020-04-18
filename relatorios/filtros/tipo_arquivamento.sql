-- permite filtrar se quer arquivo definitivo ou provisorio
-- tb_processo proc
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
