-- [N992]
-- [R133545] Retirar CLE cadastrada entre set/19 e nov/19
-- [R139182] exibir arquivamentos a partir de 2020 e melhorar performance,
-- pois nao consegue baixar a planilha para todos os OJ
-- Apos as melhorias, baixa em cerca de 40 segundos. foi o melhor que consegui.
-- EXPLAIN   ANALYZE
WITH
 natureza_cle_execucao AS (
     SELECT  nclet.id_natureza_clet
     FROM    tb_natureza_clet nclet
     WHERE nclet.tp_natureza = 'E'
     AND nclet.in_ativo = 'S'
     LIMIT 1
 )
, movimento_extincao_execucao  AS (
    SELECT ev.id_evento_processual
    FROM tb_evento_processual ev
    WHERE ev.cd_evento = '196'
    LIMIT 1
)
, movimento_arq_def AS (
    SELECT ev.id_evento_processual
    FROM tb_evento_processual ev
    WHERE ev.cd_evento = '246'
    LIMIT 1
)
   -- 246 - definitvamente, 245 -- provisoriamente
   -- 893 - desarquivados os autos
, movimento_arquiva_desarquiva AS (
    SELECT ev.id_evento_processual
    FROM tb_evento_processual ev
    WHERE ev.cd_evento IN ('246', '245', '893')
)
,arquivados_definitivamente as (
    select
        pe.id_processo
        ,pe.dt_atualizacao dt_arquivamento
    FROM tb_processo_evento pe
    WHERE
            pe.dt_atualizacao >= '01/01/2020'::date
      AND pe.id_evento = (SELECT id_evento_processual FROM movimento_arq_def)
      AND NOT EXISTS(
                SELECT 1 FROM tb_processo_evento extincao_execucao
                WHERE extincao_execucao.id_processo = pe.id_processo AND
                extincao_execucao.id_evento = (SELECT id_evento_processual FROM movimento_extincao_execucao)
        )
    -- Assyst R133545
  AND NOT EXISTS (
        SELECT 1 FROM tb_processo_clet cle
        WHERE cle.dh_cadastro_clet:: date BETWEEN to_date('01/09/2019','DD/MM/YYYY') AND to_date('14/11/2019','DD/MM/YYYY')
          and cle.id_processo_trf = pe.id_processo
    )
)
select
    'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " "
    , cj.ds_classe_judicial_sigla AS "Classe"
    ,'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
         ||p.nr_processo AS "Processo"
    ,REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) AS "Órgão Julgador"
    ,to_char(ad.dt_arquivamento, 'dd/mm/yyyy') AS "Data do Arquivamento"
    ,pt.nm_tarefa as "Tarefa"
from
    arquivados_definitivamente ad
    INNER JOIN tb_processo p ON p.id_processo = ad.id_processo
    INNER JOIN tb_processo_tarefa pt ON pt.id_processo_trf = ad.id_processo
    INNER JOIN tb_processo_trf ptrf ON ptrf.id_processo_trf = ad.id_processo
    INNER JOIN tb_orgao_julgador oj ON (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)

where
  -- RN01 - processo deve ter iniciado a execução / Processos da CLE são consideradosde acordo com a sua natureza
    (exists (
             select 1
             from
                 tb_processo_clet pclet
             where
                pclet.id_processo_trf = ad.id_processo
               -- Assyst R133545
               AND pclet.dh_cadastro_clet:: date NOT BETWEEN
                    to_date('01/09/2019','DD/MM/YYYY') AND to_date('14/11/2019','DD/MM/YYYY')
                AND pclet.id_natureza_clet = (SELECT id_natureza_clet FROM natureza_cle_execucao)
         )
        or exists (
             select 1
             from
                 tb_processo_evento prev
                     join
                 tb_evento_processual ev on (prev.id_evento = ev.id_evento_processual)
             where
                     ev.cd_evento = '11385'
               and prev.dt_atualizacao < ad.dt_arquivamento
               and prev.id_processo_evento_excludente is null
               and prev.id_processo = ad.id_processo
         ))
  --Incluir o parâmetro de filtro OJ
  AND oj.id_orgao_julgador = COALESCE(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
  AND cj.ds_classe_judicial NOT ILIKE 'Carta%'
  AND
  --Processo deve estar arquivado definitivamente RN02 e RN03
  -- nao existe nenhum movimento de arquivamento ou desarquivamento posterior ao movimento escolhido
    NOT EXISTS
        ( SELECT 1
          FROM tb_processo_evento prev
          WHERE
                prev.id_processo_evento_excludente IS NULL
                AND
            prev.id_processo = ad.id_processo
            AND prev.id_evento IN (SELECT id_evento_processual FROM movimento_arquiva_desarquiva)
            AND prev.dt_atualizacao > ad.dt_arquivamento

-- order by oj.ds_orgao_julgador, p.nr_processo
        )



