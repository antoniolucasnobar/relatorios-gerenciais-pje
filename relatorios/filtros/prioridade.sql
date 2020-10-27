(select COALESCE(string_agg(prioridade.ds_prioridade::character varying, ', '), '-')
        from
        tb_proc_prioridde_processo tabela_ligacao
        inner join tb_prioridade_processo prioridade
            on (tabela_ligacao.id_prioridade_processo = prioridade.id_prioridade_processo)
        where
        tabela_ligacao.id_processo_trf = p.id_processo
    ) AS "Prioridades"

    AND CASE :COM_PRIORIDADE
        WHEN 1 THEN EXISTS (
            SELECT 1 FROM tb_proc_prioridde_processo prio WHERE prio.id_processo_trf = p.id_processo
        )
        WHEN 0 THEN NOT EXISTS (
            SELECT 1 FROM tb_proc_prioridde_processo prio WHERE prio.id_processo_trf = p.id_processo
        )
        ELSE TRUE
     END
