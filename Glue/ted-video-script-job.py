import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import collect_list, col, struct

args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
spark.conf.set("spark.mongodb.write.socketTimeoutMS", "120000")  # 2 minuti
spark.conf.set("spark.mongodb.write.connectionTimeoutMS", "60000")  # 1 minuto
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

df_details = glueContext.create_dynamic_frame.from_catalog(database="ted_video_db", table_name="details_csv").toDF()
df_final = glueContext.create_dynamic_frame.from_catalog(database="ted_video_db", table_name="final_list_csv").toDF()
df_images = glueContext.create_dynamic_frame.from_catalog(database="ted_video_db", table_name="images_csv").toDF()
df_related = glueContext.create_dynamic_frame.from_catalog(database="ted_video_db",
                                                           table_name="related_videos_csv").toDF()
df_tags = glueContext.create_dynamic_frame.from_catalog(database="ted_video_db", table_name="tags_csv").toDF()

# =========================
# 1. CAST ID A STRINGA (Fondamentale!)
# =========================
df_details = df_details.withColumn("id", col("id").cast("string"))
df_final = df_final.withColumn("id", col("id").cast("string"))
df_images = df_images.withColumn("id", col("id").cast("string"))
df_related = df_related.withColumn("id", col("id").cast("string"))
df_tags = df_tags.withColumn("id", col("id").cast("string"))
# =========================
# AGGREGAZIONE TABELLE 1:N (evita la moltiplicazione)
# =========================

# Tags: raggruppa per id e crea array di stringhe
df_tags_agg = df_tags.groupBy("id").agg(collect_list("tag").alias("tags"))

# Related videos: raggruppa e crea array di struct (oggetti)
# (sostituisci field1, field2 con i nomi reali delle colonne di related_videos)
df_related_agg = df_related.groupBy("id").agg(
    collect_list(struct([col(c) for c in df_related.columns if c != "id"])).alias("related_videos")
)

# Images: raggruppa e crea array
df_images_agg = df_images.groupBy("id").agg(
    collect_list(struct([col(c) for c in df_images.columns if c != "id"])).alias("images")
)

# =========================
# 3. JOIN FINALE
# =========================
df = df_details \
    .join(df_final, "id", "left") \
    .join(df_tags_agg, "id", "left") \
    .join(df_related_agg, "id", "left") \
    .join(df_images_agg, "id", "left")

row_count = df.count()
print(f"📊 Totale righe generate dal join: {row_count}")
print(f"📋 Colonne nel DataFrame: {len(df.columns)}")
df.printSchema()
# =========================
# SCRITTURA SU MONGODB
# =========================


df.write \
    .format("mongodb") \
    .option("spark.mongodb.write.connection.uri",
            "mongodb+srv://ted_user:ICxk4Gv2fRmTFzq5@cluster0.yxb8l1z.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0") \
    .option("spark.mongodb.write.database", "ted_video_db") \
    .option("spark.mongodb.write.collection", "videos") \
    .option("spark.mongodb.write.maxBatchSize", "1000") \
    .option("spark.mongodb.write.ordered", "false") \
    .mode("overwrite") \
    .save()
print("✅ Dati scritti su MongoDB")

job.commit()
print("🎉 Job completato")