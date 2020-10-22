-- [T988][agrupado por OJ]
-- EXPLAIN ANALYZE
    select
          REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) AS "Órgão Julgador"
        , COUNT (oj.id_orgao_julgador) AS "Quantidade"
        , '$URL/execucao/T991?ORGAO_JULGADOR_TODOS='||oj.id_orgao_julgador
        as "Ver Processos"
--     'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " "
--          , 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||p.nr_processo as "Processo"
--          , ptrf.dt_autuacao AS "Data Autuação"
--          , cj.ds_classe_judicial_sigla AS "Classe"
--          , REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) AS "Órgão Julgador"
--          , cargo.cd_cargo as "Cargo"
--          , fase.nm_agrupamento_fase as "Fase"
--          , pt.nm_tarefa AS "Tarefa Atual"
--          , pt.dh_criacao_tarefa AS "Desde"
    from tb_processo p
             INNER JOIN tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
             join tb_processo_trf ptrf on (p.id_processo = ptrf.id_processo_trf)
             INNER JOIN tb_orgao_julgador oj ON (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
             join tb_classe_judicial cj on (cj.id_classe_judicial = ptrf.id_classe_judicial)
             inner join tb_orgao_julgador_cargo ojc ON (ptrf.id_orgao_julgador_cargo = ojc.id_orgao_julgador_cargo)
             inner join tb_cargo cargo ON (ojc.id_cargo = cargo.id_cargo)
             INNER JOIN tb_processo_tarefa pt ON pt.id_processo_trf = p.id_processo
--              INNER JOIN tb_processo_assunto pass ON (pass.id_processo_trf = p.id_processo)
--              INNER JOIN tb_assunto_trf assunto ON (assunto.in_ativo = 'S'
--                                                 AND assunto.id_assunto_trf = pass.id_assunto_trf)
         -- somente canceladas ou redesignadas
    where p.id_agrupamento_fase != 5
      AND
        CASE
            -- assuntos
            -- 5079,5077,55481,Embargos de Terceiro
            -- 5078,5077,55480,Ação Anulatória
            -- 5077,5076,11786,Atos executórios
            WHEN cj.ds_classe_judicial_sigla LIKE 'Cart%' THEN
                NOT EXISTS(
                    SELECT 1 FROM
                        tb_processo_assunto pass
                            INNER JOIN tb_assunto_trf assunto ON (assunto.in_ativo = 'S'
                            AND assunto.id_assunto_trf = pass.id_assunto_trf)
                    WHERE (pass.id_processo_trf = p.id_processo) AND assunto.cd_assunto_trf IN ('55480', '55481', '11786')
                    )
            WHEN cj.ds_classe_judicial_sigla IN ('ExFis', 'ExProvAS') THEN FALSE
            ELSE TRUE
        END
      --Processo não deve estar arquivado RN06 e nem na instância superior RN10
      AND pt.nm_tarefa not in ('Arquivo', 'Arquivo provisório', 'Arquivo definitivo', 'Arquivamento Provisório',
                           'Arquivamento Definitivo', 'Aguardando apreciação da instância superior',
                           'Aguardando apreciação pela instância superior')
      -- Não trazer audiencias se alguma outra audiencia foi realizada no mesmo horário ou posterior
      AND NOT EXISTS(
            SELECT 1
            FROM tb_processo_audiencia pa2
            WHERE pa2.id_processo_trf = ptrf.id_processo_trf
            AND (pa2.cd_status_audiencia = 'F'
                OR (pa2.cd_status_audiencia = 'M'
                    AND pa2.dt_inicio > current_timestamp
                    )
            )
        )
      AND NOT EXISTS(
          SELECT * FROM tb_processo_documento doc
          where doc.id_processo = ptrf.id_processo_trf
          AND doc.in_ativo = 'S'
          AND doc.id_tipo_processo_documento = 62
        )
      --Incluir o parâmetro de filtro OJ
      AND oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
      AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
      AND ((:CARGO is null) or (position(:CARGO in ojc.ds_cargo) > 0))
      AND ptrf.dt_autuacao :: date between
        coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('year', current_date))::date
        AND (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
      AND pt.id_tarefa = COALESCE(:TAREFA, pt.id_tarefa)
        AND cj.id_classe_judicial = COALESCE(:CLASSE_PROCESSUAL, cj.id_classe_judicial)
        GROUP BY oj.id_orgao_julgador, oj.ds_orgao_julgador
order by oj.ds_orgao_julgador
