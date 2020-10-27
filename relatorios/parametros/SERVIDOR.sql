SELECT null, 'TODOS'
UNION ALL
(SELECT ul.id_usuario, ul.ds_nome FROM tb_pessoa_servidor servidor
                                           INNER JOIN tb_usuario_login ul ON
    ( servidor.id = ul.id_usuario AND ul.in_ativo = 'S') ORDER BY ul.ds_nome)
