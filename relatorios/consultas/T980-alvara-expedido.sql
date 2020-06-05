-- [R138932][T980]

SELECT
    'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " "
    ,'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
         ||p.nr_processo as "Processo"
    ,REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade"
    , alvara.dt_juntada AS "Data do Alvará"
    ,COALESCE(ppe.nm_pessoa_parte, 'Destinatário Indefinido') AS "Destinatário"
    ,CASE ppe.in_fechado
        WHEN 'S' THEN 'Sim'
        WHEN 'N' THEN 'Não'
    END AS "Fechado"
    , pt.nm_tarefa AS "Tarefa Atual"
FROM
tb_processo_documento alvara
INNER JOIN tb_tipo_processo_documento tipo
    ON alvara.id_tipo_processo_documento = tipo.id_tipo_processo_documento
INNER JOIN tb_processo p ON (alvara.id_processo = p.id_processo)
inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
INNER JOIN tb_processo_tarefa pt ON pt.id_processo_trf = p.id_processo
inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
INNER JOIN tb_processo_expediente exp ON alvara.id_processo_documento = exp.id_processo_documento
INNER JOIN tb_proc_parte_expediente ppe ON exp.id_processo_expediente = ppe.id_processo_expediente
WHERE
    -- 76,Alvará,S,,,73
    tipo.cd_documento = '73'
    AND p.id_agrupamento_fase <> 5
    AND alvara.in_ativo = 'S'
    AND alvara.dt_juntada :: date between
      coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and
      (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
    AND oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
    AND
        CASE
            WHEN  length(TRIM(COALESCE(:PRAZO_FECHADO_ABERTO, ''))) = 0 THEN TRUE
            ELSE ppe.in_fechado = :PRAZO_FECHADO_ABERTO
        END
    AND pt.id_tarefa = COALESCE(:TAREFA, pt.id_tarefa)



