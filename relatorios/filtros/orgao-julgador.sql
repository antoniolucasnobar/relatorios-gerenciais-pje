-- select / coluna
    ,REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) AS "Órgão Julgador"

-- join
    INNER JOIN tb_orgao_julgador oj ON (oj.id_orgao_julgador = ptrf.id_orgao_julgador)

-- filtro
  AND oj.id_orgao_julgador = COALESCE(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
