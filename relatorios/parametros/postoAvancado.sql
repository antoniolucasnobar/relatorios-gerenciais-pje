SELECT null, 'TODOS' union all (
SELECT oj.id_orgao_julgador, oj.ds_orgao_julgador from tb_orgao_julgador oj
join tb_jurisdicao j using (id_jurisdicao)
INNER JOIN tb_tipo_orgao_julgador_instancia tipo_oj_instancia ON (oj.id_tipo_orgao_julgador_instancia = tipo_oj_instancia.id_tipo_orgao_julgador_instancia)
INNER JOIN tb_tipo_orgao_julgador tipo_oj ON ( tipo_oj_instancia.id_tipo_orgao_julgador = tipo_oj.id_tipo_orgao_julgador)
 WHERE 
tipo_oj.cd_tipo_orgao_julgador IN  ('POSTO-AVANCADO', 'CEJUSC')
order by j.ds_jurisdicao, nr_vara)

  -- (SELECT tipo.ds_orgao_julgador
  --  FROM tb_orgao_julgador oj
  --  inner join tb_tipo_orgao_julgador_instancia t ON (oj.id_tipo_orgao_julgador_instancia = t.id_tipo_orgao_julgador_instancia)
  --  INNER JOIN tb_tipo_orgao_julgador tipo ON (t.id_tipo_orgao_julgador = tipo.id_tipo_orgao_julgador)
  --  WHERE oj.id_orgao_julgador = desloc.dt_retorno) as "Tipo",


-- deprecated -- usando ate ter o GRANT nas tabelas
select null, 'TODOS' union all (
select oj.id_orgao_julgador, oj.ds_orgao_julgador from tb_orgao_julgador oj
join tb_jurisdicao j using (id_jurisdicao)
 WHERE 
 oj.in_posto_avancado = TRUE OR oj.in_cejusc = TRUE
order by j.ds_jurisdicao, nr_vara)
