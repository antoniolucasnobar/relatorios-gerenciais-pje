-- SELECT - campos
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

--JOIN
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
-- FILTRO
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