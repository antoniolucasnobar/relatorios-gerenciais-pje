-- #Título
-- Processos Remetidos ou Devolvidos para Posto Avançado, CEJUSC ou JAEP

-- #Código
-- T997

-- #Nome no menu
-- Processos Remetidos ou Devolvidos para Posto Avançado, CEJUSC ou JAEP

-- #Menu superior
-- Vara

-- #Glossário
-- Lista os processos que foram enviados de uma VT para um Posto avançado, CEJUSC ou JAEP, bem como os devolvidos dessas unidades para a VT de origem
-- <br />
-- <br />
-- <ul>
-- <li><strong>Remetidos</strong> - lista os processos que foram remetidos e <strong>estão</strong> no Posto avançado.
-- Ao selecionar esta opção, o filtro do período se aplica a data do envio ao Posto</li>
-- <li><strong>Devolvidos</strong> - lista os processos que foram devolvidos ao OJ de origem.
-- Ao selecionar esta opção, o filtro do período se aplica a data da devolução ao OJ de origem
-- </li>
-- </ul>
-- Onde consta "Posto avançado" aplica-se também CEJUSC / JAEP

  SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||cj.ds_classe_judicial_sigla||' '||p.nr_processo as "Processo",

    (SELECT REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' )
    FROM tb_orgao_julgador oj
    WHERE oj.id_orgao_julgador = desloc.id_oj_origem) as "Unidade",

    (SELECT REPLACE(oj.ds_orgao_julgador, 'JUÍZO AUXILIAR DE EXECUÇÃO E PRECATÓRIOS', 'JAEP' ) 
    FROM tb_orgao_julgador oj
    WHERE oj.id_orgao_julgador = desloc.id_oj_destino) as "CEJUSC / JAEP / Posto avançado",
  to_char(desloc.dt_deslocamento, 'dd/mm/yyyy hh24:mi') as "Envio ao CEJUSC / JAEP / Posto",
  to_char(desloc.dt_retorno, 'dd/mm/yyyy hh24:mi') as "Devolvido para VT",
  fase.nm_agrupamento_fase as "Fase",
  ptar.nm_tarefa as "Tarefa"
  from tb_processo p
  join tb_processo_trf ptrf on p.id_processo = ptrf.id_processo_trf
  join tb_processo_tarefa ptar on (p.id_processo = ptar.id_processo_trf)
  INNER JOIN pje.tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
  LEFT JOIN tb_hist_desloca_oj desloc ON p.id_processo::integer = desloc.id_processo_trf
  inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
  join tb_orgao_julgador oj on (ptrf.id_orgao_julgador = oj.id_orgao_julgador)
  where 
    fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
    AND desloc.id_oj_origem  = coalesce(:ORGAO_JULGADOR_TODOS,desloc.id_oj_origem)
    AND desloc.id_oj_destino = coalesce(:POSTO_CEJUSC,desloc.id_oj_destino)
    AND (
      ( -- remetidos
        (1 = :REMETIDO_DEVOLVIDO_POSTO)
        AND desloc.dt_deslocamento :: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
        AND desloc.dt_retorno IS NULL
      ) 
      OR
      ( -- devolvidos
        (0 = :REMETIDO_DEVOLVIDO_POSTO)
        AND desloc.dt_retorno :: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
      )
    )
  order by p.nr_processo