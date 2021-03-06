-- [R136908][T906] - Meta 6
WITH movimentos_julgamento_conhecimento AS (
    SELECT ev.id_evento_processual
    FROM tb_evento_processual ev
    WHERE  ev.cd_evento IN
           -- 941 - Declarada Incompetência - retirado, pois tera regra propria
           ( '442', '450', '452', '444',
        '471', '446', '448', '455', '466',
        '11795', '220', '50103', '221', '219',
        '472', '473', '458', '461', '459', '465',
        '462', '463', '457', '460', '464', '454')
)
, movimentos_sobrestamento_suspensao AS (
    SELECT ev.id_evento_processual
    FROM tb_evento_processual ev
    WHERE ev.cd_evento IN
        ('272', '275', '268', '12100', '50100', '898',
        '50092', '50135', '50136', '11975', '265',
        '50107', '11012', '11013', '11014', '11015')
)
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " "
    ,'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||cj
           .ds_classe_judicial_sigla||' '||p.nr_processo as "Processo"
    , pe.dt_atualizacao as "Data da Distribuição"
    , REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) AS "Unidade"
    ,(SELECT cargo.cd_cargo FROM tb_cargo cargo
         INNER JOIN tb_orgao_julgador_cargo ojc ON (
         ojc.id_cargo = cargo.id_cargo AND
         ptrf.id_orgao_julgador_cargo = ojc.id_orgao_julgador_cargo)
     ) as "Cargo"
--     , cargo.cd_cargo as "Cargo"
    ,CONCAT(
        (SELECT trim(ul1.ds_nome_consulta)
         FROM tb_usuario_login ul1
                  INNER JOIN tb_processo_parte ativo1 ON
             (ativo1.id_pessoa = ul1.id_usuario
                 AND ativo1.id_processo_trf = p.id_processo
                 AND ativo1.in_participacao in ('A')
                 AND ativo1.in_parte_principal = 'S'
                 AND ativo1.in_situacao = 'A'
                 AND ativo1.nr_ordem = 1
                 )
        )
    -- verificar se tem mais de uma parte no processo
    , (SELECT ' E OUTROS ('
                  || COUNT(pp.id_processo_trf)
                  || ')'
       FROM tb_processo_parte pp
       WHERE (pp.id_processo_trf = pe.id_processo
           AND pp.in_participacao in ('A')
           AND pp.in_parte_principal = 'S'
           AND pp.in_situacao = 'A'
                 )
       HAVING COUNT(pp.id_processo_trf) > 1
        )
    ) AS "Polo Ativo"
--     ,
-- || ' X ' ||
    ,CONCAT(

        (SELECT trim(ul1.ds_nome_consulta)
         FROM tb_usuario_login ul1
            INNER JOIN tb_processo_parte passivo1 ON
             (passivo1.id_pessoa = ul1.id_usuario
                 AND passivo1.id_processo_trf = p.id_processo
                 AND passivo1.in_participacao in ('P')
                 AND passivo1.in_parte_principal = 'S'
                 AND passivo1.in_situacao = 'A'
                 AND passivo1.nr_ordem = 1
                 )
         )
    , (SELECT ' E OUTROS ('
                  || COUNT(pp.id_processo_trf)
                  || ')'
       FROM tb_processo_parte pp
       WHERE (pp.id_processo_trf = pe.id_processo
           AND pp.in_participacao in ('P')
           AND pp.in_parte_principal = 'S'
           AND pp.in_situacao = 'A'
                 )
       HAVING COUNT(pp.id_processo_trf) > 1
        )
    ) AS "Polo Passivo"
    , fase.nm_agrupamento_fase as "Fase"
    , pt.nm_tarefa as "Tarefa"

FROM
    tb_processo_evento pe 
    INNER JOIN tb_evento_processual ev ON 
    -- codigo 26 - distribuido
        (pe.id_evento = ev.id_evento_processual AND ev.cd_evento = '26')
    inner join tb_processo p on p.id_processo = pe.id_processo
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo   
    join tb_orgao_julgador oj on (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
    inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
WHERE
    -- Somente processos no conhecimento - confirmado por Lucas - ASSTECO 08/06/2020 14:00
     p.id_agrupamento_fase = 2
--    fase.id_agrupamento_fase = coalesce(: ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
    AND oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
    -- regra 1.b - somente as seguintes classes
    -- 65 - Ação civil pública
    -- 980 - Ação de Cumprimento
    -- 63 - Ação civil coletiva
    -- 119 - Mandado de segurança coletivo
    -- 1709 - Interdito proibitório
    AND cj.cd_classe_judicial IN ('65','980','63','119', '1709')
    -- regra 1.a - antes de 2018
    AND pe.dt_atualizacao < '01/01/2018'::date
    AND (CASE
        -- regra 1.c - sem movimento de julgamento
        WHEN 
            NOT EXISTS(
                SELECT pe.id_processo FROM tb_processo_evento pe 
                WHERE p.id_processo = pe.id_processo
                AND pe.id_evento IN
                    (SELECT julgamento.id_evento_processual
                    FROM movimentos_julgamento_conhecimento julgamento)
            )
            THEN TRUE
            -- regra 1.c EXCECAO: existe mov. julgamento, mas foi reformada ou anulada posteriormente
            ELSE 
                EXISTS (
                    SELECT pe2.id_processo FROM tb_processo_evento pe2
                    INNER JOIN tb_evento_processual ev ON 
                        (pe2.id_evento = ev.id_evento_processual)
                    WHERE p.id_processo = pe2.id_processo
                    AND ev.cd_evento IN ('132')
                    AND (pe2.ds_texto_final_interno ilike '%para novo julgamento (por reforma da decisão pela instância superior)'
                        OR pe2.ds_texto_final_interno ilike '%para novo julgamento (por anulação da decisão pela instância superior)'
                    ) 
                    AND pe2.dt_atualizacao > 
                        (
                            SELECT MAX(pe.dt_atualizacao) FROM tb_processo_evento pe
                            WHERE p.id_processo = pe.id_processo
                              AND pe.id_evento IN
                                  (SELECT julgamento.id_evento_processual
                                   FROM movimentos_julgamento_conhecimento julgamento)
                        )
                      -- nao existe remessa ou transito em julgado posterior
                    AND NOT EXISTS(
                            SELECT 1 FROM tb_processo_evento remessa_ou_transito
                            WHERE remessa_ou_transito.id_processo = pe2.id_processo
                            AND remessa_ou_transito.dt_atualizacao > pe2.dt_atualizacao
                            AND (remessa_ou_transito.id_evento = 848 -- transito
                                OR
                                 (remessa_ou_transito.id_evento = 123 -- remessa
                                 AND remessa_ou_transito.ds_texto_final_interno ilike
                                    'Remetidos os autos para _rg__ jurisdicional competente%para processar recurso'
                                     )
                                )
                        )
                )
            END
    )
    AND (CASE 
         WHEN
            -- regra 1.d - Não tem movimento de sobrestamento/suspensao,
            NOT EXISTS 
            (
                SELECT pe.id_processo FROM tb_processo_evento pe 
                WHERE p.id_processo = pe.id_processo
                AND pe.id_evento IN (
                  SELECT sobrestamento.id_evento_processual
                  FROM movimentos_sobrestamento_suspensao sobrestamento
                )
            )
        THEN TRUE
        ELSE
        -- regra 1.d - ou, se tiver, tem tambem o de encerramento posteriormente
         ( EXISTS 
            (
                SELECT pe2.id_processo FROM tb_processo_evento pe2
                INNER JOIN tb_evento_processual ev ON 
                    (pe2.id_evento = ev.id_evento_processual)
                WHERE p.id_processo = pe2.id_processo
                AND ev.cd_evento IN ('50054')
                AND pe2.dt_atualizacao >
                (
                    SELECT MAX(pe.dt_atualizacao) FROM tb_processo_evento pe 
                    WHERE p.id_processo = pe.id_processo
                      AND pe.id_evento IN (
                        SELECT sobrestamento.id_evento_processual
                        FROM movimentos_sobrestamento_suspensao sobrestamento
                    )
                )
            )
        )
        END
    )
  AND CASE
          WHEN (length(TRIM(COALESCE(:NOME_PARTE, ''))) > 0 ) THEN TRUE
          ELSE EXISTS(
                  SELECT 1 FROM tb_processo_parte pp
                                    INNER JOIN tb_usuario_login usu ON (usu.id_usuario = pp.id_pessoa)
                  WHERE pp.id_processo_trf = pe.id_processo
                    AND pp.in_parte_principal = 'S'
                    AND pp.in_situacao = 'A'
                    AND pp.in_participacao in ('A','P')
                    AND usu.ds_nome_consulta LIKE '%' || TO_ASCII(UPPER(TRIM(:NOME_PARTE))) || '%'
              )
    END
  AND ((:CARGO is null) or
       (position(:CARGO in
                 (SELECT ojc.ds_cargo FROM tb_orgao_julgador_cargo ojc
                  WHERE (ptrf.id_orgao_julgador_cargo = ojc.id_orgao_julgador_cargo)
                 )
            ) > 0))
  AND
    -- regra 1.x - Declarada Incompetencia
   NOT EXISTS(
           SELECT pe.id_processo FROM tb_processo_evento pe
           WHERE p.id_processo = pe.id_processo
             AND pe.id_evento = 941
            AND NOT EXISTS(
                -- sem redistribuicao posterior
                   SELECT pe2.id_processo FROM tb_processo_evento pe2
                           INNER JOIN tb_evento_processual ev ON
                       (pe2.id_evento = ev.id_evento_processual)
                   WHERE p.id_processo = pe2.id_processo
                     AND ev.cd_evento IN ('36')
                     AND pe2.dt_atualizacao > pe.dt_atualizacao
               )
       )

