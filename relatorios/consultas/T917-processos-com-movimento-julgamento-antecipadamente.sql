-- [R][T917] Processos com sentenca parcial
-- EXPLAIN ANALYZE
WITH movimentos_julgado_antecipadamente AS
(
    SELECT id_evento_processual FROM tb_evento_processual ep
    WHERE ep.cd_evento IN ('50094', '50123')
)
select
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||p.nr_processo as "Processo",
        REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) as "Unidade",
        cargo.cd_cargo as "Cargo",
        pt.nm_tarefa as "Tarefa atual"
FROM tb_processo p
  join tb_processo_trf ptrf on p.id_processo = ptrf.id_processo_trf
  join tb_processo_tarefa ptar on (p.id_processo = ptar.id_processo_trf)
  INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
  inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
  INNER join tb_orgao_julgador oj on (ptrf.id_orgao_julgador = oj.id_orgao_julgador)
inner join tb_orgao_julgador_cargo ojc ON (ptrf.id_orgao_julgador_cargo = ojc.id_orgao_julgador_cargo)
inner join tb_cargo cargo ON (ojc.id_cargo = cargo.id_cargo)
  join tb_processo_tarefa pt on (p.id_processo = pt.id_processo_trf)

where
    oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
    AND ((:CARGO is null) or (position(:CARGO in ojc.ds_cargo) > 0))
    AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
    AND EXISTS (
        SELECT 1 FROM tb_processo_evento julgado_antecipadamente
        WHERE julgado_antecipadamente.id_processo = p.id_processo
        AND julgado_antecipadamente.id_evento
        IN (SELECT id_evento_processual FROM movimentos_julgado_antecipadamente)
    )

