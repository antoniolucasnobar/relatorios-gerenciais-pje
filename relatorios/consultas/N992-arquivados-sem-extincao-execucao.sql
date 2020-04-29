with arquivados_definitivamente as (
   select
      p.id_processo,
      p.nr_processo,
      pe.dt_atualizacao dt_arquivamento,
      oj.ds_orgao_julgador,
      cj.ds_classe_judicial_sigla,
      pt.nm_tarefa
from tb_processo_evento pe 
    INNER JOIN tb_evento_processual ev on (pe.id_evento = ev.id_evento_processual AND ev.cd_evento = '246')
    inner join tb_processo p on p.id_processo = pe.id_processo
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo   
    join tb_orgao_julgador oj on (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
   where
      --Processo deve estar arquivado definitivamente RN02 e RN03
    -- nao existe nenhum movimento de arquivamento ou desarquivamento posterior ao movimento escolhido
    NOT EXISTS
        ( SELECT 1
        FROM tb_processo_evento prev
        join tb_evento_processual ev 
            on (prev.id_evento = ev.id_evento_processual)
        where 
            -- 246 - definitvamente, 245 -- provisoriamente
            -- 893 - desarquivados os autos
            ev.cd_evento IN ('246', '245', '893')
            and prev.id_processo_evento_excludente is null
            and prev.id_processo = p.id_processo
            AND prev.dt_atualizacao > pe.dt_atualizacao
        )
      and ptrf.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, ptrf.id_orgao_julgador) --Incluir o parâmetro de filtro OJ
)
select
   'http://processo='||ad.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
   'http://processo='||ad.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||ad.ds_classe_judicial_sigla||' '||ad.nr_processo as "Processo",
   REPLACE(ad.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) as "Órgão Julgador" ,
   to_char(ad.dt_arquivamento, 'dd/mm/yyyy') as "Data do Arquivamento",
   ad.nm_tarefa as "Tarefa"
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
      -- Assyst R133545
   AND NOT EXISTS (
       SELECT 1 FROM tb_processo_clet cle
        WHERE cle.dt_inicio_clet:: date BETWEEN to_date('01/09/2019','DD/MM/YYYY') AND to_date('14/11/2019','DD/MM/YYYY')
       and cle.id_processo_trf = ad.id_processo
   )
order by ad.ds_orgao_julgador, ad.nr_processo