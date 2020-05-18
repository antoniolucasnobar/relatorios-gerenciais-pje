-- explain analyze
WITH sentencas_conhecimento_pendente AS (
SELECT  concluso.id_pessoa_magistrado,
        pen.id_processo_evento,
        pen.dt_atualizacao AS pendente_desde,
        p.id_processo,
        p.nr_processo
        -- COUNT(concluso.id_pessoa_magistrado) AS total
    FROM
    tb_conclusao_magistrado concluso
    INNER JOIN tb_processo_evento pen
    ON (pen.id_processo_evento = concluso.id_processo_evento
        AND pen.id_processo_evento_excludente IS NULL
    	and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
        AND pen.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
    INNER JOIN tb_processo p on (p.id_processo = pen.id_processo)
    WHERE
        concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
        -- concluso.in_diligencia != 'S'
        AND p.id_agrupamento_fase = 2 -- somente conhecimento
        AND NOT EXISTS(
            SELECT 1 FROM tb_processo_evento pe
            INNER JOIN tb_evento_processual ev ON
                (pe.id_evento = ev.id_evento_processual)
            WHERE pen.id_processo = pe.id_processo
            AND pe.id_processo_evento_excludente IS NULL
            AND (
                (
                    -- eh movimento de julgamento
                    ev.cd_evento IN
                    ('941', '442', '450', '452', '444',
                    '471', '446', '448', '455', '466',
                    '11795', '220', '50103', '221', '219',
                    '472', '473', '458', '461', '459', '465',
                    '462', '463', '457', '460', '464', '454'
                    )
                    -- sem movimento de reforma/anulacao posterior
                    AND
                    NOT EXISTS (
                        SELECT 1 FROM
                        tb_processo_evento reforma_anulacao
                        INNER JOIN tb_evento_processual ev
                            ON reforma_anulacao.id_evento = ev.id_evento_processual
                        INNER JOIN tb_complemento_segmentado cs
                            ON (cs.id_movimento_processo = reforma_anulacao.id_evento)
                        WHERE
                            p.id_processo = reforma_anulacao.id_processo
                            AND reforma_anulacao.id_processo_evento_excludente IS NULL
                            AND pe.dt_atualizacao <= reforma_anulacao.dt_atualizacao
                            AND ev.cd_evento = '132'
                            AND cs.ds_texto IN ('7098', '7131', '7132', '7467', '7585')
                    )

                )
                OR
                (
                    pe.dt_atualizacao > pen.dt_atualizacao AND
                    (
                        -- Convertido o julgamento em dilig_ncia
                        -- o movimento abaixo nao deve ser considerado para proferidas
                        ev.cd_evento = '11022'
                        OR
                            (
                                -- teve um novo concluso pra sentenca
                                ev.cd_evento = '51' AND
                                pe.ds_texto_final_interno ilike 'Concluso%proferir senten_a%'
                            )
                    )
                )
            )
        )
)
,
sentencas_conhecimento_pendentes_por_magistrado  AS (
    SELECT  sentencas_conhecimento_pendente.id_pessoa_magistrado,
        COUNT(sentencas_conhecimento_pendente.id_pessoa_magistrado) AS pendentes_sentenca
    FROM sentencas_conhecimento_pendente
    GROUP BY sentencas_conhecimento_pendente.id_pessoa_magistrado
)
,
-- T952
sentencas_conhecimento_proferidas AS (
    select
    -- ul.ds_nome,
    assin.id_pessoa,
    doc.dt_juntada,
    doc.id_processo
    from tb_processo_documento doc
    inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
    -- inner join tb_usuario_login ul on (ul.id_usuario = assin.id_pessoa)
    -- inner join pje.tb_tipo_processo_documento tipo using (id_tipo_processo_documento)
    inner join lateral (
        select pen.ds_texto_final_interno FROM
        tb_conclusao_magistrado concluso
        INNER JOIN tb_processo_evento pen
            ON (pen.id_processo_evento = concluso.id_processo_evento
                and pen.id_processo = doc.id_processo
                AND pen.id_processo_evento_excludente IS NULL
                and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                -- AND pen.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
            )
        where pen.dt_atualizacao < doc.dt_juntada
        order by pen.dt_atualizacao desc
        limit 1
    ) concluso on TRUE
    where doc.in_ativo = 'S'
    AND doc.id_tipo_processo_documento = 62
    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    -- and tipo.cd_documento = '7007'
    and doc.dt_juntada :: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
    and concluso.ds_texto_final_interno ilike 'Concluso%proferir senten_a%'
    --  nao pode ter "Extinta a execução ou o cumprimento da sentença por ..." lancado junto com a sentenca
    and not exists (
                        select 1 from tb_processo_evento extinta_execucao
                        where extinta_execucao.id_processo = doc.id_processo and
                        date(doc.dt_juntada) = date(extinta_execucao.dt_atualizacao)
                        AND extinta_execucao.id_evento = 196
 				)
)
,
sentenca_conhecimento_proferidas_por_magistrado AS (
    SELECT  sentencas_conhecimento_proferidas.id_pessoa,
        COUNT(sentencas_conhecimento_proferidas.id_pessoa) AS proferidas_sentenca
    FROM sentencas_conhecimento_proferidas
    GROUP BY sentencas_conhecimento_proferidas.id_pessoa
)
,
-- T954
pendentes_execucao AS (
         SELECT  concluso.id_pessoa_magistrado,
                 pen.id_processo_evento,
                 pen.dt_atualizacao AS pendente_desde,
                 p.id_processo,
                 p.nr_processo
                 -- COUNT(concluso.id_pessoa_magistrado) AS total
         FROM
             tb_conclusao_magistrado concluso
                 INNER JOIN tb_processo_evento pen
                            ON (pen.id_processo_evento = concluso.id_processo_evento
                                AND pen.id_processo_evento_excludente IS NULL
                                -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                                and pen.id_evento = 51
                                -- Conclusão do tipo "Julgamento da ação incidental"
                                AND (
                                            pen.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da ação incidental na execu__o%'
                                        OR pen.ds_texto_final_interno ilike 'Conclusos os autos para julgamento dos Embargos _ Execu__o%'
                                        OR pen.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da Impugna__o _ Sentença de Liquida__o%'
                                    )
                                )
                 INNER JOIN tb_processo p on (p.id_processo = pen.id_processo)
             -- INNER JOIN LATERAL (
             --     SELECT doc.dt_juntada FROM tb_processo_documento doc WHERE
             --     doc.id_processo = pen.id_processo
             --     AND doc.dt_juntada < pen.dt_atualizacao
             --     AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipos_documento)
             --     ORDER BY doc.dt_juntada DESC LIMIT 1
             -- ) peticao ON TRUE
         WHERE
                 concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
           -- concluso.in_diligencia != 'S'
           AND p.id_agrupamento_fase = 4 -- somente execucao --
           AND NOT EXISTS(
                 SELECT 1 FROM tb_processo_evento pe
                                   INNER JOIN tb_evento_processual ev ON
                     (pe.id_evento = ev.id_evento_processual)
                 WHERE pen.id_processo = pe.id_processo
                   AND pe.id_processo_evento_excludente IS NULL
                   AND (pe.dt_atualizacao > pen.dt_atualizacao
                     -- OR
                     -- pe.dt_atualizacao BETWEEN peticao.dt_juntada AND pen.dt_atualizacao
                     )
                   AND (
                     (
                         -- eh movimento de julgamento
-- 50086 - Encerrada a conclusão
-- 219   - Julgado(s) procedente(s) o(s) pedido(s) (#{classe processual}/ #{nome do incidente}) de #{nome da parte}
-- 221   - Julgado(s) procedente(s) em parte o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
-- 220   - Julgado(s) improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
-- 50013 - Julgado(s) liminarmente improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
-- 50050 - Extinto com resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
-- 50048 - Extinto sem resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
-- 50087 - Baixado o incidente/ recurso (#{nome do incidente} / #{nome do recurso}) sem decisão, onde nome do recurso deve corresponder a Embargos à Execução ou Impugnação à Sentença de Liquidação
-- 50049 - Prejudicado o incidente #{nome do incidente} de #{nome da parte}
                                 ev.cd_evento IN
                                 ('50086', '219', '221', '220', '50013', '50050', '50048')
                             OR
                                 (
                                     --nome do complemento bate com o da conclusao
                                                 ev.cd_evento = '50087' AND
                                                 (pen.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%' and pe.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%')
                                         OR (pen.ds_texto_final_interno ilike '%Embargos à Execução%' and pe.ds_texto_final_interno ilike '%Embargos à Execução%')
                                         OR (pen.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da ação incidental na execu__o%'
                                         and (pe.ds_texto_final_interno ilike '%Embargos à Execução%'
                                             OR pe.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%'
                                                 )
                                                     )
                                     )
-- 50049 - Prejudicado o incidente #{nome do incidente} de #{nome da parte}
                             OR
                                 (
                                     --nome do complemento bate com o da conclusao
                                             ev.cd_evento = '50049' AND
                                             pe.ds_texto_final_interno ilike ANY
                                             (ARRAY['Prejudicado o incidente Impugnação à Sentença de Liquidação%',
                                                 'Prejudicado o incidente Embargos à Execução%']
                                                 )
                                     )
                         )
                     )
             )
     )
, sentencas_pendentes_execucao AS (
    SELECT  pendentes_execucao.id_pessoa_magistrado,
            -- COUNT(pendentes_execucao.id_pessoa_magistrado) AS total,
            COUNT(pendentes_execucao.id_pessoa_magistrado) AS pendentes_sentenca
    FROM pendentes_execucao
    GROUP BY pendentes_execucao.id_pessoa_magistrado
)
,
-- T956
     tipos_doc_embargos_exec_impug_sentenca_liq AS (
       --16	Embargos à Execução	S			7143
       --32	Impugnação à Sentença de Liquidação	S			53
       select id_tipo_processo_documento
       from tb_tipo_processo_documento
       where cd_documento = '7007'
         and in_ativo = 'S'
     ),
     movimentos_julgado_incidentes_execucao AS (
       SELECT ev.id_evento_processual
       FROM tb_evento_processual ev
       WHERE
         -- eh movimento de julgamento
-- 219   - Julgado(s) procedente(s) o(s) pedido(s) (#{classe processual}/ #{nome do incidente}) de #{nome da parte}
-- 221   - Julgado(s) procedente(s) em parte o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
-- 220   - Julgado(s) improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
-- 50013 - Julgado(s) liminarmente improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
-- 50050 - Extinto com resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
-- 50048 - Extinto sem resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
         ev.cd_evento IN
         ('219', '221', '220', '50013', '50050', '50048')
     )
    ,
     incidentes_execucao_julgados AS (
       select
         -- ul.ds_nome,
         assin.id_pessoa,
         doc.dt_juntada,
         doc.id_processo,
         iniciada_execucao.dt_atualizacao
       from tb_processo_documento doc
              inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
              INNER JOIN tb_processo_evento iniciada_execucao
                         ON (iniciada_execucao.id_processo = doc.id_processo
                           AND iniciada_execucao.id_evento = 11385)
       where doc.in_ativo = 'S'
         -- 62
         AND doc.id_tipo_processo_documento =  (
         SELECT id_tipo_processo_documento FROM tipos_doc_embargos_exec_impug_sentenca_liq
       )
         AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
         -- and tipo.cd_documento = '7007'
         -- so pega documentos juntados depois do inicio da execucao
         and doc.dt_juntada between GREATEST(iniciada_execucao.dt_atualizacao, :DATA_INICIAL) and (:DATA_FINAL)
         AND EXISTS (
           SELECT 1 FROM
             tb_processo_evento pen
           WHERE
               pen.id_processo = doc.id_processo
             AND pen.id_processo_evento_excludente IS NULL
             and pen.id_evento IN (
             SELECT id_evento_processual FROM movimentos_julgado_incidentes_execucao
           )
             AND date(doc.dt_juntada) = date(pen.dt_atualizacao)
             AND  pen.ds_texto_final_interno ilike ANY (
             ARRAY['%Impugnação à Sentença de Liquidação%',
               '%Embargos à Execução%']
             )
         )

     )
,
 incidentes_execucao_julgados_por_magistrado AS (
    SELECT  incidentes_execucao_julgados.id_pessoa,
            COUNT(incidentes_execucao_julgados.id_pessoa) AS julgados_execucao
    FROM incidentes_execucao_julgados
    GROUP BY incidentes_execucao_julgados.id_pessoa
  )
,
-- T958
  pendentes_embargos_declaratorio AS (
  SELECT  concluso.id_pessoa_magistrado,
  pen.id_processo_evento,
  pen.dt_atualizacao AS pendente_desde,
  p.id_processo,
  p.nr_processo
  FROM
  tb_conclusao_magistrado concluso
  INNER JOIN tb_processo_evento pen
  ON (pen.id_processo_evento = concluso.id_processo_evento
  AND pen.id_processo_evento_excludente IS NULL
-- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
  and pen.id_evento = 51
-- Conclusão do tipo "Julgamento dos Embargos de Declara__o"
  AND
  pen.ds_texto_final_interno ilike
  'Conclusos os autos para julgamento dos Embargos de Declara__o%'
  )
  INNER JOIN tb_processo p on (p.id_processo = pen.id_processo)
-- INNER JOIN LATERAL (
--     SELECT doc.dt_juntada FROM tb_processo_documento doc WHERE
--     doc.id_processo = pen.id_processo
--     AND doc.dt_juntada < pen.dt_atualizacao
--     AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipo_documento_embargo_declaracao)
--     ORDER BY doc.dt_juntada DESC LIMIT 1
-- ) peticao ON TRUE -- //ver comentario na definicao do tipo_documento_embargo_declaracao
  WHERE p.id_agrupamento_fase <> 5
  AND concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
  AND NOT EXISTS(
  SELECT 1 FROM tb_processo_evento pe
  INNER JOIN tb_evento_processual ev ON
   (pe.id_evento = ev.id_evento_processual)
  WHERE pen.id_processo = pe.id_processo
  AND pe.id_processo_evento_excludente IS NULL
  AND pe.dt_atualizacao > pen.dt_atualizacao
  AND
   (
-- NÃO Existir um movimento dentre os seguintes, após o concluso
-- 50086 - Encerrada a conclusão
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa}
-- 230 - Prejudicado(s) o(s) #{nome do recurso} de #{nome da parte}
  ev.cd_evento IN
   ('50086', '198', '871', '200', '235', '230')
  OR
   (
--nome do complemento bate com Embargos de Declara__o%
  ev.cd_evento IN ('235', '230') AND
  pe.ds_texto_final_interno ilike '%Embargos de Declara__o%'
  )
  )
  )
  )
,
   embargos_declaratorios_pendentes AS (
    SELECT  pendentes_embargos_declaratorio.id_pessoa_magistrado,
            COUNT(pendentes_embargos_declaratorio.id_pessoa_magistrado) AS pendentes_embargo
    FROM pendentes_embargos_declaratorio
    GROUP BY pendentes_embargos_declaratorio.id_pessoa_magistrado
  )
,
     tipo_documento_sentenca AS (
       --62	Sentença	S			7007
       select id_tipo_processo_documento
       from tb_tipo_processo_documento
       where cd_documento = '7007'
         and in_ativo = 'S'
     ),
     movimentos_embargos_declaracao_julgados AS (
       SELECT ev.id_evento_processual
       FROM tb_evento_processual ev
       WHERE
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa}
ev.cd_evento IN
('198', '871', '200', '235')
     )
    ,
     embargos_declaracao_julgados AS (
       select
         assin.id_pessoa,
         doc.dt_juntada,
         doc.id_processo
       from tb_processo_documento doc
              inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
              inner join lateral (
         select pen.ds_texto_final_interno FROM
           tb_conclusao_magistrado concluso
             INNER JOIN tb_processo_evento pen
                        ON (pen.id_processo_evento = concluso.id_processo_evento
                          and pen.id_processo = doc.id_processo
                          AND pen.id_processo_evento_excludente IS NULL
                          and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                          -- AND pen.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
                          )
         where pen.dt_atualizacao < doc.dt_juntada
         order by pen.dt_atualizacao desc
         limit 1
         ) concluso on TRUE
       where doc.in_ativo = 'S'
         AND doc.id_tipo_processo_documento = (SELECT id_tipo_processo_documento FROM tipo_documento_sentenca)
         AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
         and doc.dt_juntada :: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
         and concluso.ds_texto_final_interno ilike 'Conclusos os autos para julgamento dos Embargos de Declara__o%'
         AND EXISTS (
           SELECT 1 FROM
             tb_processo_evento pen
           WHERE
               pen.id_processo = doc.id_processo
             AND pen.id_processo_evento_excludente IS NULL
             and pen.id_evento IN (
             SELECT id_evento_processual FROM movimentos_embargos_declaracao_julgados
           )
             AND date(doc.dt_juntada) <= date(pen.dt_atualizacao)
         -- AND  pen.ds_texto_final_interno ilike '%Embargos de Declara__o%'
         )
     )
, embargo_declaracao_julgado AS (
  SELECT  embargos_declaracao_julgados.id_pessoa,
          COUNT(embargos_declaracao_julgados.id_pessoa) AS quantidade_julgado
  FROM embargos_declaracao_julgados
  GROUP BY embargos_declaracao_julgados.id_pessoa
)
SELECT ul.ds_nome AS "Magistrado",
       coalesce(sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca, 0)
          AS "Sentenças de conhecimento pendentes",
        '$URL/execucao/T951?MAGISTRADO='
          ||sentencas_conhecimento_pendentes_por_magistrado.id_pessoa_magistrado
          ||'&texto='||sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca
         AS  "Detalhes"
       , -- "Ver Pendentes",
       -- T952
       coalesce(sentenca_conhecimento_proferidas_por_magistrado.proferidas_sentenca, 0)
        AS  "Sentenças de Conhecimento Proferidas" -- "Ver Pendentes"
        ,
       '$URL/execucao/T953?MAGISTRADO='||sentenca_conhecimento_proferidas_por_magistrado.id_pessoa
           ||'&DATA_INICIAL='||to_char(:DATA_INICIAL::date,'mm/dd/yyyy')
           ||'&DATA_FINAL='||to_char(:DATA_FINAL::date,'mm/dd/yyyy')
           ||'&texto='||sentenca_conhecimento_proferidas_por_magistrado.proferidas_sentenca
         as "Detalhes" -- "Ver Proferidas"
, -- T954
       coalesce(sentencas_pendentes_execucao.pendentes_sentenca, 0)
         AS "Incidentes de Execução Pendentes",
       '$URL/execucao/T955?MAGISTRADO='
         ||sentencas_pendentes_execucao.id_pessoa_magistrado
         ||'&texto='||sentencas_pendentes_execucao.pendentes_sentenca
         as "Detalhes"-- "Ver Incidentes de Execução Pendentes"
,
-- T956
       coalesce(incidentes_execucao_julgados_por_magistrado.julgados_execucao, 0)
     AS "Incidendentes de Execução Julgados"
    ,
       '$URL/execucao/T957?MAGISTRADO='||incidentes_execucao_julgados_por_magistrado.id_pessoa
         ||'&DATA_INICIAL='||to_char(:DATA_INICIAL::date,'mm/dd/yyyy')
         ||'&DATA_FINAL='||to_char(:DATA_FINAL::date,'mm/dd/yyyy')
         ||'&texto='||incidentes_execucao_julgados_por_magistrado.julgados_execucao
         as "Detalhes" --  "Ver Incidendentes de Execução Julgados"
-- T958
,
       coalesce(embargos_declaratorios_pendentes.pendentes_embargo, 0) AS "Embargos Declaratórios Pendentes",
       '$URL/execucao/T959?MAGISTRADO='||embargos_declaratorios_pendentes.id_pessoa_magistrado||'&texto='||embargos_declaratorios_pendentes.pendentes_embargo
         as  "Detalhes" -- "Ver Embargos Declaratórios Pendentes"
-- T960
,
       coalesce(embargo_declaracao_julgado.quantidade_julgado, 0) AS "Embargos Declaratórios Julgados"
    ,
       '$URL/execucao/T961?MAGISTRADO='||embargo_declaracao_julgado.id_pessoa
         ||'&DATA_INICIAL='||to_char(:DATA_INICIAL::date,'mm/dd/yyyy')
         ||'&DATA_FINAL='||to_char(:DATA_FINAL::date,'mm/dd/yyyy')
         ||'&texto='||embargo_declaracao_julgado.quantidade_julgado
         as  "Detalhes" -- "Ver Julgados"

FROM tb_pessoa_magistrado mag
    LEFT JOIN sentencas_conhecimento_pendentes_por_magistrado
        ON (mag.id =
            sentencas_conhecimento_pendentes_por_magistrado.id_pessoa_magistrado)
    LEFT JOIN sentenca_conhecimento_proferidas_por_magistrado
        ON (sentenca_conhecimento_proferidas_por_magistrado.id_pessoa =
            mag.id )
   LEFT JOIN sentencas_pendentes_execucao
       ON (sentencas_pendentes_execucao.id_pessoa_magistrado =
           mag.id )
   LEFT JOIN incidentes_execucao_julgados_por_magistrado
      ON (incidentes_execucao_julgados_por_magistrado.id_pessoa =
        mag.id )
   LEFT JOIN embargos_declaratorios_pendentes
             ON (embargos_declaratorios_pendentes.id_pessoa_magistrado =
                 mag.id )
   LEFT JOIN embargo_declaracao_julgado
             ON (embargo_declaracao_julgado.id_pessoa =
                 mag.id )
   INNER JOIN tb_usuario_login ul
       ON (ul.id_usuario = mag.id )
WHERE
    mag.id = coalesce(:MAGISTRADO, mag.id)
AND (   coalesce(sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca, 0)
        + coalesce(sentenca_conhecimento_proferidas_por_magistrado.proferidas_sentenca, 0)
        + coalesce(sentencas_pendentes_execucao.pendentes_sentenca, 0)
        + coalesce(incidentes_execucao_julgados_por_magistrado.julgados_execucao, 0)
        + coalesce(embargos_declaratorios_pendentes.pendentes_embargo, 0)
        + coalesce(embargo_declaracao_julgado.quantidade_julgado, 0)
    ) > 0
ORDER BY ul.ds_nome
