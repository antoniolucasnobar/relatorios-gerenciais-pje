 -- R136909  - falta glossario e titulo
  SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||cj.ds_classe_judicial_sigla||' '||p.nr_processo as "Processo",
    to_char(ptrf.dt_autuacao,'dd/MM/yyyy') as "Data da Autuação",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) as "Unidade",
    cargo.cd_cargo as "Cargo",

    (SELECT trim(ul1.ds_nome) FROM tb_usuario_login ul1 WHERE ativo1.id_pessoa = ul1.id_usuario) 
    || CASE
        WHEN (ativo2.id_pessoa IS NOT NULL) THEN ' E OUTROS (' ||
            (SELECT COUNT(pp.id_processo_trf) FROM tb_processo_parte pp
                WHERE (pp.id_processo_trf = p.id_processo
                        AND pp.in_participacao in ('A')
                        AND pp.in_parte_principal = 'S'
                        AND pp.in_situacao = 'A'
                        )
            ) || ')'
        ELSE ''
    END AS "Polo Ativo"
    ,
-- || ' X ' ||
    (SELECT trim(ul1.ds_nome) FROM tb_usuario_login ul1 WHERE passivo1.id_pessoa = ul1.id_usuario) 
    || CASE
        WHEN (passivo2.id_processo_trf IS NOT NULL) THEN ' E OUTROS (' ||
            (SELECT COUNT(pp.id_processo_trf) FROM tb_processo_parte pp
                WHERE (pp.id_processo_trf = p.id_processo
                        AND pp.in_participacao in ('P')
                        AND pp.in_parte_principal = 'S'
                        AND pp.in_situacao = 'A'
                        )
            ) || ')'
        ELSE ''
    END AS "Polo Passivo",
    (SELECT ta.ds_tipo_audiencia || ' - ' || pa.dt_inicio
        FROM tb_processo_audiencia pa
        join tb_tipo_audiencia ta using (id_tipo_audiencia)
        WHERE pa.id_processo_trf = ptrf.id_processo_trf
            AND pa.cd_status_audiencia = 'F' 
            and pa.in_ativo = 'S'
        ORDER BY pa.dt_inicio DESC
        LIMIT 1        
    ) AS "Última Audiência",
substring(UPPER(TRIM(fase.nm_agrupamento_fase)) FROM 0 FOR 4) || ' / ' || 
                ptar.nm_tarefa as "Fase / Tarefa Atual"  
FROM tb_processo p
  join tb_processo_trf ptrf on p.id_processo = ptrf.id_processo_trf
  join tb_processo_tarefa ptar on (p.id_processo = ptar.id_processo_trf)
  INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
  inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
  INNER join tb_orgao_julgador oj on (ptrf.id_orgao_julgador = oj.id_orgao_julgador)
inner join tb_orgao_julgador_cargo ojc ON (ptrf.id_orgao_julgador_cargo = ojc.id_orgao_julgador_cargo)
inner join tb_cargo cargo ON (ojc.id_cargo = cargo.id_cargo)
--   INNER JOIN tb_processo_assunto pass ON (pass.id_processo_trf = p.id_processo)
--   INNER JOIN tb_assunto_trf assunto ON (assunto.in_ativo = 'S' 
--     AND assunto.id_assunto_trf = pass.id_assunto_trf)
                INNER JOIN tb_processo_parte ativo1 ON 
                        (ativo1.id_processo_trf = p.id_processo
                                AND ativo1.in_participacao in ('A')
                                AND ativo1.in_parte_principal = 'S'
                                AND ativo1.in_situacao = 'A'
                                AND ativo1.nr_ordem = 1
                        )
                INNER JOIN tb_processo_parte passivo1 ON 
                        (passivo1.id_processo_trf = p.id_processo
                                AND passivo1.in_participacao in ('P')
                                AND passivo1.in_parte_principal = 'S'
                                AND passivo1.in_situacao = 'A'
                               AND passivo1.nr_ordem = 1
                        )
                 LEFT JOIN tb_processo_parte ativo2 ON 
                        (ativo2.id_processo_trf = p.id_processo
                                AND ativo2.in_participacao in ('A')
                                AND ativo2.in_parte_principal = 'S'
                                AND ativo2.in_situacao = 'A'
                                AND ativo2.nr_ordem = 2
                        )
                  LEFT JOIN tb_processo_parte passivo2 ON 
                        (passivo2.id_processo_trf = p.id_processo
                                AND passivo2.in_participacao in ('P')
                                AND passivo2.in_parte_principal = 'S'
                                AND passivo2.in_situacao = 'A'
                                AND passivo2.nr_ordem = 2
                        )              
where 
    oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
    AND ((:CARGO is null) or (position(:CARGO in ojc.ds_cargo) > 0))
    AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
    AND fase.id_agrupamento_fase != 5
                    and (ptrf.dt_autuacao BETWEEN to_timestamp(:DATA_INICIAL, 'yyyy-MM-dd' )
                           and (to_timestamp(:DATA_FINAL, 'yyyy-MM-dd' ) + interval '24 hours'))

    AND
    CASE 
    -- assunto.ds_assunto_trf = 'COVID-19' AND
    WHEN (:COVID_PRIORIDADE = 0) THEN EXISTS (
        SELECT 1 FROM 
            tb_processo_assunto pass
            INNER JOIN tb_assunto_trf assunto ON (assunto.in_ativo = 'S' 
                AND assunto.id_assunto_trf = pass.id_assunto_trf)
            WHERE (pass.id_processo_trf = p.id_processo) AND assunto.ds_assunto_trf = 'COVID-19'
    )
    WHEN (:COVID_PRIORIDADE = 1) THEN EXISTS (
        SELECT 1 FROM tb_proc_prioridde_processo prio WHERE prio.id_processo_trf = p.id_processo
    )
    -- Rito Sumario e Sumarissimo
    WHEN (:COVID_PRIORIDADE = 2) THEN (
        cj.cd_classe_judicial = ANY('{1125,1126}'::text[]) 
    )
    -- tutela antecipada
    WHEN (:COVID_PRIORIDADE = 3) THEN 
    NOT EXISTS (
        SELECT pe.id_processo FROM tb_processo_evento pe 
                INNER JOIN tb_evento_processual ev ON 
                    (pe.id_evento = ev.id_evento_processual)
                WHERE p.id_processo = pe.id_processo
                AND ev.cd_evento IN ('50132')
                AND NOT EXISTS (
                    SELECT tut.id_processo FROM tb_processo_evento tut 
                            INNER JOIN tb_evento_processual ev ON 
                                (tut.id_evento = ev.id_evento_processual)
                            WHERE p.id_processo = tut.id_processo
                            AND ev.cd_evento IN ('85')    
                            AND (tut.ds_texto_final_interno ilike 'Juntada a petição de Tutela%')                     
                            AND tut.dt_atualizacao > pe.dt_atualizacao
                )    
    )
    AND 
    (
        -- classes de tutela
        cj.cd_classe_judicial = ANY('{12134,12135}'::text[]) 
        -- dado estruturado processo
        OR
        ptrf.in_tutela_liminar = 'S' AND ptrf.in_apreciado_tutela_liminar = 'N'
        -- movimento do tipo de peticao
        OR 
        EXISTS (
            SELECT pe.id_processo FROM tb_processo_evento pe 
                    INNER JOIN tb_evento_processual ev ON 
                        (pe.id_evento = ev.id_evento_processual)
                    WHERE p.id_processo = pe.id_processo
                    AND ev.cd_evento IN ('85')    
                    AND (pe.ds_texto_final_interno ilike 'Juntada a petição de Tutela%') 
        )   
    )
    END
                AND ((:NOME_PARTE is null) or 
                        ( 
                          (:NOME_PARTE is NOT null) AND
                          EXISTS(
                                SELECT 1 FROM tb_processo_parte pp
                                INNER JOIN tb_usuario_login usu ON (usu.id_usuario = pp.id_pessoa)
                                WHERE pp.id_processo_trf = p.id_processo
                                AND pp.in_parte_principal = 'S'
                                AND pp.in_situacao = 'A'
                                AND pp.in_participacao in ('A','P')
                                AND usu.ds_nome_consulta LIKE '%' || UPPER(:NOME_PARTE) || '%'
                          )  
                        )
                ) 