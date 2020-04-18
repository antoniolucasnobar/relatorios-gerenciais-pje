-- adicionar como coluna
    fase.nm_agrupamento_fase as "Fase",
-- JOIN
    -- tb_processo proc
    inner join tb_agrupamento_fase fase on (proc.id_agrupamento_fase = fase.id_agrupamento_fase)
-- adicionar como filtro
    AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)