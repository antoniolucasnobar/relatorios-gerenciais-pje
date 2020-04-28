-- coluna JT/JS
                cargo.cd_cargo as "Cargo",
-- coluna extendida
                ojc.ds_cargo as "Cargo",
-- JOINS
                inner join tb_orgao_julgador_cargo ojc ON (ptrf.id_orgao_julgador_cargo = ojc.id_orgao_julgador_cargo)
                inner join tb_cargo cargo ON (ojc.id_cargo = cargo.id_cargo)
-- FILTRO 
                ((:CARGO is null) or (position(:CARGO in ojc.ds_cargo) > 0))

